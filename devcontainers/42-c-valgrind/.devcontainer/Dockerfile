FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Install C/C++ compilation tools, debugging tools, and Valgrind
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y --no-install-recommends \
        build-essential \
        clang \
        clang-format \
        clang-tidy \
        lldb \
        gdb \
        valgrind \
        make \
        cmake \
        git \
        curl \
        python3-pip \
        python3-venv \
        libbsd-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install 42 Norminette (C code style linter)
RUN python3 -m pip install --no-cache-dir --break-system-packages norminette
