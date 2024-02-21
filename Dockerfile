FROM --platform=${BUILDPLATFORM} impactaky/mc-ubuntu22.04-${TARGETARCH}-host:2.0.0 as mimic-host

## Build heavy packages such as libtorch_vendor

FROM docker.io/hakuturu583/cuda_ros:lt4-humble-cuda-12.2.2-devel as build_base_stage
SHELL ["/bin/bash", "-c"]

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y \
    python3-vcstool git python3-colcon-common-extensions python3-rosdep \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p robocup_ws/src
WORKDIR robocup_ws/src
ADD workspace.repos .
RUN vcs import . < workspace.repos
WORKDIR ../
ENV USE_NCCL 0
ENV USE_DISTRIBUTED 1
ENV TORCH_CUDA_ARCH_LIST 8.7
RUN mkdir /base_packages
RUN rosdep init && rosdep update
RUN source /opt/ros/$ROS_DISTRO/setup.bash && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
    rosdep install -iry --from-paths src \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY --from=mimic-host / /mimic-cross
RUN /mimic-cross/mimic-cross.deno/setup.sh

RUN source /opt/ros/$ROS_DISTRO/setup.bash && \
    MIMIC_CROSS_DISABLE=1 colcon build --install-base /base_packages \
        # --cmake-args -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
        #     -DCMAKE_CXX_FLAGS="-march=armv8.2-a;-mtune=cortex-a78ae;-mcpu=cortex-a78ae" \
        #     -DCMAKE_C_FLAGS="-march=armv8.2-a;-mtune=cortex-a78ae;-mcpu=cortex-a78ae" \
        --event-handlers console_cohesion+

## Build robocup software

FROM docker.io/hakuturu583/cuda_ros:lt4-humble-cuda-12.2.2-devel as build_stage
RUN mkdir /base_packages
COPY --from=build_base_stage /base_packages /base_packages
SHELL ["/bin/bash", "-c"]

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y \
    python3-vcstool git python3-colcon-common-extensions python3-rosdep \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p robocup_ws/src
WORKDIR robocup_ws/src
ADD workspace.repos .
RUN vcs import . < workspace.repos
WORKDIR ../
ENV USE_NCCL 0
ENV USE_DISTRIBUTED 1
ENV TORCH_CUDA_ARCH_LIST 8.7
RUN rosdep init && rosdep update
RUN source /opt/ros/$ROS_DISTRO/setup.bash && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
    rosdep install -iry --from-paths src \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
RUN rm -rf src/*

ADD entrypoint.sh /
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
