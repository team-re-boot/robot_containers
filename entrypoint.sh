#!/bin/bash

set -e
source /opt/ros/$ROS_DISTRO/setup.bash

source /base_packages/local_setup.bash

echo "$@"
exec "$@"
