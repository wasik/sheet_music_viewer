# sheet_music_viewer

Organize and view your sheet music

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://flutter.dev/docs/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://flutter.dev/docs/cookbook)

For help getting started with Flutter, view our
[online documentation](https://flutter.dev/docs), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


## Development Environment With Docker 

If you don't want to install development tools to "bare metal", it is possible to 
run the whole development environment as a docker container and to connect to it 
from e.g. VSCode remote. (Credits: https://dev.to/ameysunu/dockerize-your-flutter-app-3feg)

To start the development container, cd to the root project directory and run: 

    docker compose up

This command will firs check if the docker image, built with `Dockerfile` from this project, exists. 
If image is not found, it will be built, which may take several minutes. The image will contain 
all necessary linux, android and flutter tools. After that you can run for example VSCode and with 
command "Attach to a running container" chose the "sheet-music-viewer..." container, and access 
the project within container's /project directory