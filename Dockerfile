# Use the official ROS Melodic base image
FROM ros:melodic

# Set environment variables
ARG USERNAME=henk
ARG USER_UID=1000
ARG USER_GID=$USER_UID
ARG DEBIAN_FRONTEND=noninteractive
ENV ROS_WORKSPACE=/home/${USERNAME}/kuka_sigma7_impedance_ws

# Install essential dependencies
RUN apt-get update && apt-get install -y \
    git \
    cmake \
    build-essential \
    python-catkin-tools \
    python-rosdep \
    python-pip \
    wget \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user
RUN groupadd --gid $USER_GID $USERNAME && \
    useradd -m -s /bin/bash --uid $USER_UID --gid $USER_GID $USERNAME && \
    mkdir -p /home/$USERNAME/.ros && \
    chown -R $USER_UID:$USER_GID /home/$USERNAME

# Add the user to the sudo group
RUN echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME && \
    chmod 0440 /etc/sudoers.d/$USERNAME

# Set up ROS environment
RUN echo "source /opt/ros/melodic/setup.bash" >> /etc/bash.bashrc && \
    echo "source ${ROS_WORKSPACE}/devel/setup.bash" >> /etc/bash.bashrc

# Initialize rosdep
RUN if [ -f /etc/ros/rosdep/sources.list.d/20-default.list ]; then \
    sudo rm -f /etc/ros/rosdep/sources.list.d/20-default.list; \
fi && rosdep init && rosdep update

# Copy the entire workspace
COPY . ${ROS_WORKSPACE}
WORKDIR ${ROS_WORKSPACE}

# Initialize and update Git submodules
RUN git submodule update --init --recursive

# Install external libraries (KUKA FRI, SpaceVecAlg, RBDyn, mc_rbdyn_urdf, corrade, robot_controllers)
RUN cd ${ROS_WORKSPACE}/src && \
    git clone --recursive https://github.com/jrl-umi3218/SpaceVecAlg.git && \
    cd SpaceVecAlg && mkdir build && cd build && cmake .. && make -j && sudo make install && \
    cd ${ROS_WORKSPACE}/src && \
    git clone --recursive https://github.com/jrl-umi3218/RBDyn.git && \
    cd RBDyn && mkdir build && cd build && cmake .. && make -j && sudo make install && \
    cd ${ROS_WORKSPACE}/src && \
    git clone --recursive https://github.com/jrl-umi3218/mc_rbdyn_urdf.git && \
    cd mc_rbdyn_urdf && mkdir build && cd build && cmake .. && make -j && sudo make install && \
    cd ${ROS_WORKSPACE}/src && \
    git clone https://github.com/mosra/corrade.git && \
    cd corrade && git checkout 0d149ee9f26a6e35c30b1b44f281b272397842f5 && mkdir build && cd build && cmake .. && make -j && sudo make install && \
    cd ${ROS_WORKSPACE}/src && \
    git clone https://github.com/epfl-lasa/robot_controllers.git && \
    cd robot_controllers && mkdir build && cd build && cmake .. && make -j && sudo make install

# Build the workspace using catkin_make
RUN /bin/bash -c "source /opt/ros/melodic/setup.bash && catkin_make"

# Run container as non-root user
USER $USERNAME

# Set the default command
CMD ["bash"]
