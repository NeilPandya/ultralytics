#! /bin/bash

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

xhost + && docker run \
	-i \
	-t \
	--name ultralytics-qat-export \
	-h ultralytics-qat-export \
	--gpus=all \
	--rm \
	-w /ultralytics \
	neilpandya/ultralytics:8.3.233-torch2.9.1-zen3-sm86-qat-export \
	bash
