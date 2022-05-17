# fcf-editor
GD&T feature control frame editor experiment

Elm frontend + Rust backed demonstration for immediate model update

For parsing the text version 'pest' is used, the backend is based on 'actix-web'

# build on windows
elm, rust must be installed
use the 'frontends/build.bat'
in backend 'cargo build'
then run the backend/target/debug/backend.exe to start the local webserver
go to http://localhost:7878 to access the frontend in the browser
