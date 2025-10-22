# To run image:
#   podman run -p 10300:10300/tcp \
#       --device /dev/dri --group-add video \
#       --security-opt seccomp=unconfined \
#       localhost/wyoming-whisper-vulkan-service

# Model:
#   Default large-v3-turbo
#   Downloaded to /opt/whisper.cpp/models during `podman build`
#   To override:
#       podman run -v /your/model/dir:/opt/whisper.cpp/models ...
#            localhost/wyoming-whisper-vulkan-service -m <model-path>
#
ARG WHISPER_MODEL=large-v3-turbo

# Language:
#   Default en
#   To override:
#       podman run ... \
#           localhost/wyoming-whisper-vulkan-service -l <lang>
ARG WHISPER_LANG=en

# Wyoming host interface and port:
#   Default all interfaces
#   To override:
#       podman run -p 127.0.0.1:10300:10300/tcp ...
#           localhost/wyoming-whisper-vulkan-service 
ARG WYOMING_PORT=10300/tcp

FROM registry.fedoraproject.org/fedora:rawhide AS builder

RUN dnf -y --nodocs install \
        git python3-pip bash cmake g++ \
        vulkan-loader-devel vulkaninfo mesa-vulkan-drivers glslc \
    && dnf clean all && rm -rf /var/cache/dnf/*

WORKDIR /opt/whisper.cpp
RUN git clone https://github.com/ggml-org/whisper.cpp.git .

RUN git clean -xdf \
    && cmake -B build -DGGML_VULKAN=1 \
    && cmake --build build -j --config Release

ARG WHISPER_MODEL
RUN models/download-ggml-model.sh ${WHISPER_MODEL}

WORKDIR /opt/whisper.cpp/inst_libs
RUN cp -a /opt/whisper.cpp/build/src/libwhisper.* ./
RUN cp -a /opt/whisper.cpp/build/ggml/src/libggml* ./
RUN cp -a /opt/whisper.cpp/build/ggml/src/ggml-vulkan/libggml-vulkan.* ./

WORKDIR /opt/wyoming-whisper-api-client
RUN git clone https://github.com/ser/wyoming-whisper-api-client.git .
RUN script/setup
RUN .venv/bin/python3 setup.py install

FROM registry.fedoraproject.org/fedora-minimal:rawhide AS toolbox

RUN microdnf -y --nodocs --setopt=install_weak_deps=0 install \
        bash ncurses ca-certificates libstdc++ libgcc libatomic libgomp \
        vulkan-loader vulkaninfo mesa-vulkan-drivers python3 \
    && microdnf clean all && rm -rf /var/cache/dnf/*

ARG WHISPER_MODEL
WORKDIR /opt/whisper.cpp/models
COPY --from=builder /opt/whisper.cpp/models/ggml-${WHISPER_MODEL}.bin .

WORKDIR /opt/wyoming-whisper-api-client
COPY --from=builder /opt/whisper.cpp/build/bin /usr/bin
COPY --from=builder /opt/whisper.cpp/inst_libs/ /usr/lib64/
COPY --from=builder /opt/wyoming-whisper-api-client/.venv .venv

CMD ["/bin/bash"]

FROM registry.fedoraproject.org/fedora-minimal:rawhide AS default

RUN microdnf -y --nodocs --setopt=install_weak_deps=0 install \
        bash ncurses ca-certificates libstdc++ libgcc libatomic libgomp \
        vulkan-loader vulkaninfo mesa-vulkan-drivers python3 \
    && microdnf clean all && rm -rf /var/cache/dnf/*

ARG WHISPER_MODEL
ARG WHISPER_LANG
ARG WYOMING_PORT

WORKDIR /opt/whisper.cpp/models
COPY --from=builder /opt/whisper.cpp/models/ggml-${WHISPER_MODEL}.bin .

WORKDIR /opt/wyoming-whisper-api-client
COPY --from=builder /opt/whisper.cpp/build/bin /usr/bin
COPY --from=builder /opt/whisper.cpp/inst_libs/ /usr/lib64/
COPY --from=builder /opt/wyoming-whisper-api-client/.venv .venv

WORKDIR /opt/wyoming-whisper-vulkan-service
ADD run.sh .

EXPOSE ${WYOMING_PORT}
ENTRYPOINT ["/opt/wyoming-whisper-vulkan-service/run.sh"]
CMD ["-m ${WHISPER_MODEL}", "-l ${WHISPER_LANG}"]
