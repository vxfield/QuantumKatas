FROM alpine:latest

ARG QSHARP_VERSION=0.11.2003.3107
ARG JUPYTER_PORT=8888
ARG NB_USER="jovyan"
ARG NB_UID="1000"
ARG NB_GID="100"

EXPOSE $JUPYTER_PORT
CMD jupyter notebook --ip=0.0.0.0 --port=$JUPYTER_PORT --notebook-dir=$HOME/QuantumKatas/

# DOTNET RUNTIME DEPENDENCIES
# FROM mcr.microsoft.com/dotnet/core/runtime-deps:3.1-alpine3.10
# https://github.com/dotnet/dotnet-docker/blob/dcb185a49e2ed8e7a40cf4bbce522853ba5f1b8d/3.0/runtime-deps/alpine3.10/amd64/Dockerfile

# DOTNET SDK
# FROM mcr.microsoft.com/dotnet/core/sdk:3.1-alpine3.10 AS DotNetSDKBase
# https://github.com/dotnet/dotnet-docker/blob/50e95cd9af6458ce0db21e6ec952e29c3ee1fadf/3.1/sdk/alpine3.10/amd64/Dockerfile

ENV \
    # Add metadata indicating that this image is used for the katas.
        IQSHARP_HOSTING_ENV=KATAS_DOCKERFILE \
    #DOTNET VARIABLES
        # Enable detection of running in a container
        DOTNET_RUNNING_IN_CONTAINER=true \
        DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false \
        # Enable correct mode for dotnet watch (only mode supported in a container)
        DOTNET_USE_POLLING_FILE_WATCHER=true \
        LC_ALL=en_US.UTF-8 \
        LANG=en_US.UTF-8 \
        # Skip extraction of XML docs - generally not useful within an image/container - helps performance
        NUGET_XMLDOC_MODE=skip \
    # Other variables
        QSHARP_VERSION=$QSHARP_VERSION \
        JUPYTER_PORT=$JUPYTER_PORT \
        SHELL=/bin/bash \
        NB_USER=$NB_USER \
        NB_UID=$NB_UID \
        NB_GID=$NB_GID \
        LANGUAGE=en_US.UTF-8 \
        PATH=$PATH:$HOME/.dotnet/tools \
        DOTNET_ROOT=/usr/share/dotnet

RUN apk add --no-cache \
    #
        ca-certificates \
        bash \
        git \
    # The Quantum Simulator dependencies
        libgomp \
    # .NET Core dependencies
        krb5-libs \
        libgcc \
        libintl \
        libssl1.1 \
        libstdc++ \
        zlib \
    # Add dependencies for disabling invariant mode (set in base image)
        icu-libs \
    # Python3 and dependencies
        libpng \
        freetype \
        python3 \
        py2-pip \
        libzmq

# Install .NET Core SDK
RUN dotnet_sdk_version=3.1.101 \
    && wget -O dotnet.tar.gz https://dotnetcli.azureedge.net/dotnet/Sdk/$dotnet_sdk_version/dotnet-sdk-$dotnet_sdk_version-linux-musl-x64.tar.gz \
    && dotnet_sha512='ce386da8bc07033957fd404909fc230e8ab9e29929675478b90f400a1838223379595a4459056c6c2251ab5c722f80858b9ca536db1a2f6d1670a97094d0fe55' \
    && echo "$dotnet_sha512  dotnet.tar.gz" | sha512sum -c - \
    && mkdir -p /usr/share/dotnet \
    && tar -C /usr/share/dotnet -oxzf dotnet.tar.gz \
    && ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet \
    && rm dotnet.tar.gz \
    # Trigger first run experience by running arbitrary cmd
    && dotnet --info

# INSTALL PYTHON3, NOTEBOOK, JUPYTER, QSHARP, NUMPY, MATPLOTLIB, PYTEST

RUN \
    # Add some temporary packages for pip builds
        apk add --update --no-cache --virtual .build-tmp \
            gcc \
       	    build-base \
            python3-dev \
       	    libpng-dev \
       	    musl-dev \
       	    freetype-dev \
            zeromq-dev && \
    # Install Python packages
        pip3 install --upgrade pip setuptools wheel && \
        pip3 install -I \
                            notebook==6.0.2 \
                            jupyter==1.0.0  \
                            jupyter-client==5.3.4 \
                            numpy==1.18.1  \
                            matplotlib==3.1.2  \
                            pytest==5.3.4 \
                            qsharp==$QSHARP_VERSION && \
    # Remove the temporary build packages
        apk del .build-tmp

# SETUP USER
# FROM jupyter/base-notebook:python-3.7.3 AS JupyterBase
# https://github.com/jupyter/docker-stacks/blob/master/base-notebook/Dockerfile

RUN adduser -s /bin/bash -u $NB_UID -D -G users $NB_USER && \
    chmod g+w /etc/passwd

USER $NB_UID

# Install IQSharp
RUN dotnet tool install --no-cache -g Microsoft.Quantum.IQSharp --version $QSHARP_VERSION && \
    $HOME/.dotnet/tools/dotnet-iqsharp install --user

RUN cd $HOME && \
    git clone https://github.com/microsoft/QuantumKatas.git && \
    cd QuantumKatas && \
    rm NuGet.config && \
    chmod +x ./scripts/*.sh && \
    ./scripts/prebuild-kata.sh BasicGates && \
    ./scripts/prebuild-kata.sh CHSHGame && \
    ./scripts/prebuild-kata.sh DeutschJozsaAlgorithm && \
    ./scripts/prebuild-kata.sh GHZGame && \
    ./scripts/prebuild-kata.sh GraphColoring && \
    ./scripts/prebuild-kata.sh GroversAlgorithm && \
    ./scripts/prebuild-kata.sh JointMeasurements && \
    ./scripts/prebuild-kata.sh KeyDistribution_BB84 && \
    ./scripts/prebuild-kata.sh MagicSquareGame && \
    ./scripts/prebuild-kata.sh Measurements && \
    ./scripts/prebuild-kata.sh PhaseEstimation && \
    ./scripts/prebuild-kata.sh QEC_BitFlipCode && \
    ./scripts/prebuild-kata.sh RippleCarryAdder && \
    ./scripts/prebuild-kata.sh SolveSATWithGrover && \
    ./scripts/prebuild-kata.sh SuperdenseCoding && \
    ./scripts/prebuild-kata.sh Superposition && \
    ./scripts/prebuild-kata.sh Teleportation && \
    ./scripts/prebuild-kata.sh UnitaryPatterns && \
    ./scripts/prebuild-kata.sh tutorials/ComplexArithmetic ComplexArithmetic.ipynb && \
    ./scripts/prebuild-kata.sh tutorials/ExploringDeutschJozsaAlgorithm DeutschJozsaAlgorithmTutorial.ipynb && \
    ./scripts/prebuild-kata.sh tutorials/ExploringGroversAlgorithm ExploringGroversAlgorithmTutorial.ipynb && \
    ./scripts/prebuild-kata.sh tutorials/LinearAlgebra LinearAlgebra.ipynb && \
    ./scripts/prebuild-kata.sh tutorials/MultiQubitGates MultiQubitGates.ipynb && \
    ./scripts/prebuild-kata.sh tutorials/MultiQubitSystems MultiQubitSystems.ipynb && \
    ./scripts/prebuild-kata.sh tutorials/Qubit Qubit.ipynb && \
    ./scripts/prebuild-kata.sh tutorials/SingleQubitGates SingleQubitGates.ipynb

RUN echo "<?xml version=\"1.0\" encoding=\"utf-8\"?>\
          <configuration>\
              <packageSources>\
                   <clear />\
              </packageSources>\
          </configuration>\
    " > ${HOME}/.nuget/NuGet/NuGet.Config
