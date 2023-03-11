# syntax=docker/dockerfile:1
ARG DEBIAN_FRONTEND=noninteractive
ARG DEBIAN_PRIORITY=critical
ARG PIP_PREFER_BINARY=1

FROM python:3.10-bullseye AS app
LABEL com.nvidia.volumes.needed=nvidia_driver

# Pull pre-FROM args into environment
ARG DEBIAN_FRONTEND
ARG DEBIAN_PRIORITY
ARG PIP_PREFER_BINARY

# set shell
SHELL [ "/bin/bash", "-c" ]

# Get nVidia repo key and add to apt sources
ARG CUDA_REPO_URL=https://developer.download.nvidia.com/compute/cuda/repos/debian11/x86_64
RUN curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/debian11/x86_64/3bf863cc.pub \
    | gpg --dearmor -o /etc/apt/trusted.gpg.d/cuda.gpg \
  && echo "deb ${CUDA_REPO_URL} /" >/etc/apt/sources.list.d/cuda.list

# Install torch support libs
RUN --mount=type=cache,target=/var/cache/apt apt-get update \
  && apt-get -y install --no-install-recommends \
    ca-certificates \
    libjpeg-dev \
    libpng-dev \
  && apt-get clean

# Install CUDNN
ARG CUDA_VERSION=11.8
ARG CUDNN_VERSION=8.8.1.3-1+cuda11.8
RUN --mount=type=cache,target=/var/cache/apt apt-get update \
  && apt-get -y install --no-install-recommends \
    "cuda-toolkit-${CUDA_VERSION/\./-}" \
    "libcudnn8=${CUDNN_VERSION}" \
  && apt-get clean

# update pip
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m pip install --upgrade pip wheel

# Install PyTorch
ARG TORCH_VERSION=1.13.1+cu117
ARG TORCH_INDEX_URL=https://download.pytorch.org/whl/cu117
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m pip install torch==${TORCH_VERSION} torchvision --extra-index-url ${TORCH_INDEX_URL}

# add files
COPY . /sukima
WORKDIR /sukima

# get py dependencies
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m pip install -r requirements.txt

# dirty hack for bitsandbytes
RUN sed -i 's/cuda_setup\.add_log_entry("WARNING: Compute capability < 7.5 detected!/CUDASetup.get_instance().add_log_entry("WARNING: Compute capability < 7.5 detected!/' \
    /usr/local/lib/python3.10/site-packages/bitsandbytes/cuda_setup/main.py

# CUDA env vars
ENV NVIDIA_DRIVER_CAPABILITIES "compute,utility"
ENV NVIDIA_REQUIRE_CUDA "cuda>=11.7 driver>=450"

# set up environment variables
ENV PYTHONUNBUFFERED 1
ENV PYTHONPATH "${PYTHONPATH}:/"
ENV PORT 8000

EXPOSE ${PORT}
# set entrypoint
CMD [ "bash -l" ]
