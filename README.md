# Wyoming + Whisper.cpp w/ Vulkan backend bundle

## What?

A podman/docker image with wyoming-whisper-api-client and whisper.cpp
bundled together. whisper.cpp is built with it's Vulkan backend enabled.

[whisper.cpp](https://github.com/ggml-org/whisper.cpp)

[wyoming-whisper-api-client](https://github.com/ser/wyoming-whisper-api-client)

## Why?

The official Whisper add-on for Home Assistant, with it's default model, is
not producing accurate results for me.  Changing the model to medium-int8
produces good accuracy, but introduces considerable latency. Since I have
a machine with a resonably good iGPU for inference, I decided to give
whisper.cpp with it's Vulkan backend a try.

With the Vulkan backend I can run the large-v3-turbo model, getting excellent
accuracy and snappy responses (< 1s).

## Comments...

I use podman since my preferred distro is Fedora. docker *should* work as
a direct substitute, but I have not tested this.

I am running this on a Ryzen AI Max+ 395 w/ Radeon 8060S APU. It runs alongside
Ollama which acts as my Home Assistant conversation agent (currently using the
gpt-oss-120b model). Ollama just recently added Vulkan support (but you must
build it yourself since they are not producing builds with Vulkan yet). I have both
Speech-to-text and my conversation agent running with Vulkan acceleration on the same
machine.  No other special frameworks required (i.e. no CUDA or ROCm).

As a test, I also ran whisper.cpp CLI on a Ryzen 9 7900 APU with GFX1036 iGPU. This
is a *much* less capable iGPU.  With the large-v3-turbo model, responses to
the sample I used for testing were > 10s. With the medium model, responses were
~2s. So in general, an APU with a low end iGPU does not provide enough processing
power to run this with acceptable speed. But it should run quite nicely on any
descrete GPU that has modern Vulkan drivers.

## Build

```
podman build -f Dockerfile -t wyoming-whisper .
```

## Run

```
podman run --name=wyoming-whisper -p 10300:10300/tcp \
    --device /dev/dri --group-add video --security-opt \
    seccomp=unconfined localhost/wyoming-whisper
```

## Other configuration

### Firewall

You may need to open a firewall port to allow access to the Wyoming service port.
E.g. run this on the machine running the podman wyoming-whisper image.
```
sudo firewall-cmd --zone=FedoraServer --add-port=10300/tcp
sudo firewall-cmd --zone=FedoraServer --add-port=10300/tcp --permanent
```

### Paranoid Penguin measures

If you worry about keeping services such as this as far away from your personal
data as possible (as I do), you may want to run this in a separate user account
that does not have a password (so no external login is possible).

I document the podman way below (a.k.a. The Way™). But this can also be accomplished
with rootless docker.

Create the user account. Example user is `bob`.
```
sudo useradd -m bob
sudo usermod -L bob
```

Configure the `bob` account so it can run services upon boot and services may
continue running after `bob` logs out.
```
sudo loginctl enable-linger bob
```

Switch to `bob` user account and `/home/bob` directory
```
machinectl shell bob@
cd
```

At this point you may build the podman image and configure a user service
that will be launched whenever the machine boots. The recommended modern
way to run podman services is with Quadlets, `man podman-systemd`.
Example systemd quadlet file `wyoming-whisper.container`:
```
[Unit]
Description=Wyoming-Whisper Service

[Container]
Image=localhost/wyoming-whisper
ContainerName=wyoming-whisper
PublishPort=10300:10300/tcp
AddDevice=/dev/dri
GroupAdd=video
SeccompProfile=unconfined

[Service]
Restart=always

[Install]
WantedBy=default.target
```

Install the quadlet file:
```
podman quadlet install wyoming-whisper.container
```

The above basically just copies the file to `~/.config/containers/systemd/wyoming-whisper.container`.

The systemd daemon needs to be reloaded after adding or changing files:
```
systemctl --user daemon-reload
```

Start the systemd user service:
```
systemctl --user start wyoming-whisper.service
```

### Home Assistant

I am assuming you have previously installed the necessary componends to run
Home Assistant's voice assistant.

Go to `Settings->Devices & services` and select the `Wyoming Protocol` integration.
Select `Add service`. Fill in the host ip and port for the Wyoming server you started
above.

Go to `Settings->Voice assistants`. Select the currently configured assistant configuration
to edit it. Change the `Speech-to-text` option to the Wyoming service you just configured.

That *should* be all there is to it.
