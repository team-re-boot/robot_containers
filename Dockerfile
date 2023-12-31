FROM docker.io/hakuturu583/cuda_ros:lt4-humble-cuda-12.2.2-devel as build_stage
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
    rosdep install -iry --from-paths src && \
    colcon build --install-base /base_packages \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*