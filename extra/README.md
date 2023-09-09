# Official Triangle Linux Docker

This Triangle Linux Docker image provides a minimal base install of the latest
version of the Triangle Linux Rolling Distribution. There are no tools added
to this image, so you will need to install them yourself. 

For details about Triangle Linux metapackages, check
<https://www.trianglesec.github.io/blog/triangle-linux-metapackages/>.

# Weekly updates

Docker images are updated weekly and pushed to the Docker Hub at
<https://hub.docker.comgithub.com/trianglesectriangle>.

You can run those images with either Docker or Podman, at your convenience:

```
# Podman
podman run --rm -it triangle-rolling
# Docker
docker run --rm -it triangle/triangle-rolling
```

For more documentation, refer to:
* <https://www.trianglesec.github.io/docs/containers/using-triangle-podman-images/>
* <https://www.trianglesec.github.io/docs/containers/using-triangle-docker-images/>

# How to build those images

The easiest is probably to build via the GitLab infrastructure. All it takes is
to fork the GitLab repository, and let the CI/CD build it for you. Images are
rebuilt every time a commit is pushed, and can be found in the GitLab Registry
that is associated with your fork.

For those who prefer to build locally, there is the script `build.sh`.  A good
starting point is `./build.sh -h`.
