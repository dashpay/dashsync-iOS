install:
	git submodule update --init --recursive
	brew install cmake protobuf grpc


bootstrap: install
