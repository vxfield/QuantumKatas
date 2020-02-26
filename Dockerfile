FROM alpine:3.11.3

ARG QSHARP_VERSION=0.10.1911.1607
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
        git=2.24.1-r0 \
    # The Quantum Simulator dependencies
        libgomp=9.2.0-r3 \
    # .NET Core dependencies
        krb5-libs=1.17.1-r0 \
        libgcc=9.2.0-r3 \
        libintl=0.20.1-r2 \
        libssl1.1=1.1.1d-r3 \
        libstdc++=9.2.0-r3 \
        zlib=1.2.11-r3 \
    # Add dependencies for disabling invariant mode (set in base image)
        icu-libs=64.2-r0 \
    # Python3 and dependencies
        libpng=1.6.37-r1 \
        freetype=2.10.1-r0 \
        python3=3.8.1-r0 \
        py2-pip=18.1-r0 \
        libzmq=4.3.2-r0

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
            gcc=9.2.0-r3 \
       	    build-base=0.5-r1 \
            python3-dev=3.8.1-r0 \
       	    libpng-dev=1.6.37-r1 \
       	    musl-dev=1.1.24-r0 \
       	    freetype-dev=2.10.1-r0 \
            zeromq-dev=4.3.2-r0 && \
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

COPY ./prebuild-kata-jupyter.sh /home/jovyan/

RUN cd $HOME && \
    git clone https://github.com/microsoft/QuantumKatas.git && \
    cp prebuild-kata-jupyter.sh ./QuantumKatas/scripts/ && \
    cd QuantumKatas && \
    chmod +x ./scripts/*.sh && \
    ./scripts/prebuild-kata-jupyter.sh BasicGates && \
    ./scripts/prebuild-kata-jupyter.sh CHSHGame && \
    ./scripts/prebuild-kata-jupyter.sh DeutschJozsaAlgorithm && \
    ./scripts/prebuild-kata-jupyter.sh GHZGame && \
    ./scripts/prebuild-kata-jupyter.sh GraphColoring && \
    ./scripts/prebuild-kata-jupyter.sh GroversAlgorithm && \
    ./scripts/prebuild-kata-jupyter.sh JointMeasurements && \
    ./scripts/prebuild-kata-jupyter.sh KeyDistribution_BB84 && \
    ./scripts/prebuild-kata-jupyter.sh MagicSquareGame && \
    ./scripts/prebuild-kata-jupyter.sh Measurements && \
    ./scripts/prebuild-kata-jupyter.sh PhaseEstimation && \
    ./scripts/prebuild-kata-jupyter.sh QEC_BitFlipCode && \
    ./scripts/prebuild-kata-jupyter.sh RippleCarryAdder && \
    ./scripts/prebuild-kata-jupyter.sh SolveSATWithGrover && \
    ./scripts/prebuild-kata-jupyter.sh SuperdenseCoding && \
    ./scripts/prebuild-kata-jupyter.sh Superposition && \
    ./scripts/prebuild-kata-jupyter.sh Teleportation && \
    ./scripts/prebuild-kata-jupyter.sh UnitaryPatterns && \
    ./scripts/prebuild-kata-jupyter.sh tutorials/ComplexArithmetic ComplexArithmetic.ipynb && \
    ./scripts/prebuild-kata-jupyter.sh tutorials/ExploringDeutschJozsaAlgorithm DeutschJozsaAlgorithmTutorial.ipynb && \
    ./scripts/prebuild-kata-jupyter.sh tutorials/ExploringGroversAlgorithm ExploringGroversAlgorithmTutorial.ipynb && \
    ./scripts/prebuild-kata-jupyter.sh tutorials/LinearAlgebra LinearAlgebra.ipynb && \
    ./scripts/prebuild-kata-jupyter.sh tutorials/MultiQubitGates MultiQubitGates.ipynb && \
    ./scripts/prebuild-kata-jupyter.sh tutorials/MultiQubitSystems MultiQubitSystems.ipynb && \
    ./scripts/prebuild-kata-jupyter.sh tutorials/Qubit Qubit.ipynb && \
    ./scripts/prebuild-kata-jupyter.sh tutorials/SingleQubitGates SingleQubitGates.ipynb

# USER root
# USER $NB_UID
