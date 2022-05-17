
How to set up the build:
    - install rust: https://www.rust-lang.org/learn/get-started
        - https://win.rustup.rs/


    - To autogenerate C bindings you will need to follow: https://rust-lang.github.io/rust-bindgen/requirements.html
        - Download and install the official pre-built binary from LLVM download page.
            - http://releases.llvm.org/9.0.0/LLVM-9.0.0-win64.exe
        - set LIBCLANG_PATH as an environment variable pointing to the bin directory of your LLVM install.
        - [build-dependencies]
          bindgen = "0.51.1"
        - create build.rs
        
