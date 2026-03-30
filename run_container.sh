#! /usr/bin/bash

: << 'COMMENT'
This script won't work if you don't have a webcam or similar device
plugged in that your system has identifies as `/dev/video0`. Change or
delete this parameter to suit your needs; it was included for using a WEBCAM
in for live video input.
--device=/dev/video0 \
--shm-size=2g \
--ulimit memlock=-1 \
--ulimit stack=67108864 \
COMMENT

: << 'COMMENT'
xhost + && docker run \
	-i \
	-t \
	--name ultralytics-qat \
	-h ultralytics-qat \
	--gpus=all \
	--rm \
	-w /ultralytics \
	neilpandya/ultralytics:latest \
	bash
COMMENT

#! /usr/bin/bash

# Ensure the container can connect to the Wayland socket
# No "xhost +" required, but some compositors may need XWayland
# if the app doesn't support Wayland natively.

docker run \
    -it \
    --name ultralytics-qat \
    -h ultralytics-qat \
    --rm \
    --gpus=all \
    --device=/dev/video0 \
    --shm-size=2g \
    --env="DISPLAY=$DISPLAY" \
    --env="WAYLAND_DISPLAY=$WAYLAND_DISPLAY" \
    --env="XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR" \
    --volume="$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:/tmp/$WAYLAND_DISPLAY" \
    --env="WAYLAND_DISPLAY=/tmp/$WAYLAND_DISPLAY" \
    --volume="/tmp/.X11-unix:/tmp/.X11-unix" \
    -w /ultralytics \
    neilpandya/ultralytics:latest \
    bash
