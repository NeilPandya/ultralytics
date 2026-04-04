#! /usr/bin/bash

: << 'COMMENT'

This script won't work if you don't have a webcam or similar device
plugged in that your system has identifies as `/dev/video0`. Change or
delete this parameter to suit your needs; it was included for using a WEBCAM
in for live video input.

xhost + && docker run \
	-i \
	-t \
	--name ultralytics \
	-h ultralytics \
	--gpus=all \
	--device=/dev/video0 \
    --shm-size=2g \
    --ulimit memlock=-1 \
    --ulimit stack=67108864 \
	--rm \
	-w /ultralytics \
	neilpandya/ultralytics:latest \
	bash

- The script shows some extra `ulimit` flags (`memlock=-1`, `stack=67108864`). These are usually not needed for typical YOLO inference, but if you ever hit “locked memory” or “stack size” errors you can uncomment them and add them to the `docker run` line.
- If you are using an X11 server and find that the container can’t connect, you may need to run `xhost +local:` on the host once per session to allow local users (including the container) to open windows. The Wayland‑based approach you already have avoids this step when a Wayland compositor is in use.

COMMENT

# Ensure the container can connect to the Wayland socket
# No "xhost +" required, but some compositors may need XWayland
# if the app doesn't support Wayland natively.

docker run \
    -it \
    --name ultralytics \
    -h ultralytics \
    --rm \
    --ipc=host\
    --gpus=all \
    --device=/dev/video0 \
    --shm-size=2g \
    --env="DISPLAY=$DISPLAY" \
    --env="WAYLAND_DISPLAY=$WAYLAND_DISPLAY" \
    --env="XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR" \
    --env="WAYLAND_DISPLAY=/tmp/$WAYLAND_DISPLAY" \
    --volume="/tmp/.X11-unix:/tmp/.X11-unix" \
    --volume="$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:/tmp/$WAYLAND_DISPLAY" \
    -w /ultralytics \
    neilpandya/ultralytics:latest \
    bash
