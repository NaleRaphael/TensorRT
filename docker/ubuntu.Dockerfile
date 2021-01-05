# Copyright (c) 2020, NVIDIA CORPORATION. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

ARG CUDA_VERSION=11.1
ARG OS_VERSION=18.04

FROM nvidia/cuda:${CUDA_VERSION}-cudnn8-devel-ubuntu${OS_VERSION}

LABEL maintainer="NVIDIA CORPORATION"

ARG uid=1000
ARG gid=1000
RUN groupadd -r -f -g ${gid} trtuser && useradd -r -u ${uid} -g ${gid} -ms /bin/bash trtuser
RUN usermod -aG sudo trtuser
RUN echo 'trtuser:nvidia' | chpasswd
RUN mkdir -p /workspace && chown trtuser /workspace


# While installing `tzdata`, the whole process will suspend becasue interactive
# mode is triggered for asking user input. To solve this issue, we have
# to preset variable `TZ` before installing "software-properties-common".
# see also this link:
# https://github.com/fstab/docker-ubuntu/blob/1e7f5a2a/Dockerfile#L18-L20
# There is another solution for this, which said that we can set a env variable
# `ENV DEBIAN_FRONTEND=noninteractive` in dockerfile. However, it's not
# recommended to do this, see also this thread:
# https://github.com/moby/moby/issues/4032
RUN TZ="Asia/Taipei" \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apt-get update && apt-get install -y software-properties-common
RUN add-apt-repository ppa:ubuntu-toolchain-r/test
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    wget \
    zlib1g-dev \
    git \
    pkg-config \
    sudo \
    ssh \
    libssl-dev \
    pbzip2 \
    pv \
    bzip2 \
    unzip \
    devscripts \
    lintian \
    fakeroot \
    dh-make \
    build-essential

# NOTE: On Ubuntu 20.04, it will fail to install tensorflow-1.15.4 since the
# Python version used by system is 3.8. Therefore, we have to downgrade it to
# 3.7 since tensorflow v1 support only Python<=3.7.
RUN . /etc/os-release &&\
    if [ "$VERSION_ID" = "16.04" ]; then \
        add-apt-repository ppa:deadsnakes/ppa && apt-get update &&\
        apt-get remove -y python3 python && apt-get autoremove -y &&\
        apt-get install -y python3.6 python3.6-dev &&\
        cd /tmp && wget https://bootstrap.pypa.io/get-pip.py && python3.6 get-pip.py &&\
        python3.6 -m pip install wheel &&\
        ln -s /usr/bin/python3.6 /usr/bin/python3 &&\
        ln -s /usr/bin/python3.6 /usr/bin/python; \
    elif [ "$VERSION_ID" = "20.04" ] || [ "$VERSION_ID" = "18.04" ]; then \
        add-apt-repository ppa:deadsnakes/ppa && apt-get update &&\
        apt-get remove -y python3 python && apt-get autoremove -y &&\
        apt-get install -y python3.7 python3.7-dev &&\
        cd /tmp && wget https://bootstrap.pypa.io/get-pip.py && python3.7 get-pip.py &&\
        python3.7 -m pip install wheel &&\
        ln -sf /usr/bin/python3.7 /usr/bin/python3 &&\
        ln -sf /usr/bin/python3.7 /usr/bin/python; \
    else \
        apt-get update &&\
        apt-get install -y --no-install-recommends \
        python3 \
        python3-pip \
        python3-dev \
        python3-wheel &&\
        cd /usr/local/bin &&\
        ln -s /usr/bin/python3 python &&\
        ln -s /usr/bin/pip3 pip; \
    fi

RUN pip3 install --upgrade pip
RUN pip3 install setuptools>=41.0.0

# Install Cmake
RUN cd /tmp && \
    wget https://github.com/Kitware/CMake/releases/download/v3.14.4/cmake-3.14.4-Linux-x86_64.sh && \
    chmod +x cmake-3.14.4-Linux-x86_64.sh && \
    ./cmake-3.14.4-Linux-x86_64.sh --prefix=/usr/local --exclude-subdir --skip-license && \
    rm ./cmake-3.14.4-Linux-x86_64.sh

# Install PyPI packages
COPY requirements.txt /tmp/requirements.txt
RUN pip3 install -r /tmp/requirements.txt

# Download NGC client
RUN cd /usr/local/bin && wget https://ngc.nvidia.com/downloads/ngccli_cat_linux.zip && unzip ngccli_cat_linux.zip && chmod u+x ngc && rm ngccli_cat_linux.zip ngc.md5 && echo "no-apikey\nascii\n" | ngc config set

# Set environment and working directory
ENV TRT_RELEASE /tensorrt
ENV TRT_SOURCE /workspace/TensorRT
ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${TRT_SOURCE}/build/out:${TRT_RELEASE}/lib"
WORKDIR /workspace

USER trtuser
RUN ["/bin/bash"]
