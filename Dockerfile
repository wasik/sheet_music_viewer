FROM ubuntu:23.10 as builder
ARG DEV_TOOLS_HOME=/dev-tools
RUN apt update && apt install -y curl git unzip xz-utils zip libglu1-mesa openjdk-17-jdk wget usbutils
RUN mkdir -p /project
WORKDIR ${DEV_TOOLS_HOME}

#Installing Android SDK
ENV ANDROID_SDK_ROOT ${DEV_TOOLS_HOME}/sdk
RUN mkdir -p .android && touch .android/repositories.cfg
RUN wget -O sdk-tools.zip https://dl.google.com/android/repository/commandlinetools-linux-10406996_latest.zip
RUN unzip sdk-tools.zip && rm sdk-tools.zip
RUN mv cmdline-tools latest
RUN mkdir -p sdk/cmdline-tools
RUN mv latest sdk/cmdline-tools/
RUN cd sdk/cmdline-tools/latest/bin/ && yes | ./sdkmanager --licenses
RUN cd sdk/cmdline-tools/latest/bin/ && ./sdkmanager "build-tools;29.0.2" "patcher;v4" "platform-tools" "platforms;android-29" "sources;android-29"
ENV PATH "$PATH:$DEV_TOOLS_HOME/sdk/platform-tools"

#Installing Flutter SDK
RUN git clone https://github.com/flutter/flutter.git
ENV PATH "$PATH:$DEV_TOOLS_HOME/flutter/bin"
RUN flutter channel stable
RUN flutter upgrade
RUN flutter doctor
