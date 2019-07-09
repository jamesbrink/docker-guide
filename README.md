# No Bullshit guide for building Docker images

# About
This repository is going to serve as my guide to building solid docker images. It will likely be highly opinionated and possibly incorrect in places. pull requests and recommendations are always welcome. 

This guide is setup to be cloned locally if you would like to run through he examples. 
To do this I recommend you have the following tools available on your machine:  

* docker
* bash
* make
* jq
  
# Table of contents
- [No Bullshit guide for building Docker images](#No-Bullshit-guide-for-building-Docker-images)
- [About](#About)
- [Table of contents](#Table-of-contents)
- [Dockerfile Unraveled](#Dockerfile-Unraveled)
  - [Shell](#Shell)
  - [Instructions & Layers](#Instructions--Layers)
    - [The wrong way](#The-wrong-way)
    - [The better way](#The-better-way)
- [Base Images](#Base-Images)
  - [Always use a tagged image](#Always-use-a-tagged-image)

# Dockerfile Unraveled

First lets touch on what a `Dockerfile` actually is and how it works. Understanding what is going on here 
will ensure you are able to build cache-efficient and slim Docker images.

## Shell
At first glance a Dockerfile looks a lot like a shell script, there is a very subtle but no accidental reason for this.
By default docker build command uses `/bin/sh` on linux hosts (see [SHELL](https://docs.docker.com/engine/reference/builder/#shell)). This means you can really use any interpreter you want to build docker images. As an example, lets assume for a moment you wanted to use Ruby to build your docker images (Can't think of a sane reason why you would). 

The following Dockerfile is valid: 
```Dockerfile
FROM ruby:2.6.3-alpine3.10
SHELL [ "/usr/local/bin/ruby", "-e" ]
RUN puts Dir.pwd
RUN foo='/foo'; \
    Dir.mkdir '/foo'; \
    Dir.chdir foo; \
    puts Dir.pwd; \
    require 'fileutils'; \
    FileUtils.touch('bar.txt')
RUN exec("apk add vim")
RUN exec("ls -lart /foo/")
```

It will create a directory with and empty file called `/foo/bar.txt` and install `vim`. **The point I am trying to make is that the sh script is not really a requirement of the Dockerfile, just the default**

## Instructions & Layers

Given the information above, knowing shell scripting is helpful, but what you really need to understand more than anything is how the Dockerfile instructions are run.

Instructions are things such as `FROM`, `RUN`, `ENV`, `EXPOSE`, etc. They are always in caps and they have a 1-1 relationship with **Docker layers**. Nearly every instruction is a layer. Generally speaking less is better. This is why you will often see `RUN` commands that are in a multi-line format and strung together in a way they makes you want to throw up from looking at it. 

### The wrong way

It's important to understand that these layers are immutable in a similar way to a git commit. Take the following extreme example of how not to build Docker images. For this example we will download and build **GNU patch**

```Dockerfile
FROM alpine:3.10
RUN apk add alpine-sdk
RUN apk add wget
RUN mkdir /build
WORKDIR /build
RUN wget http://ftp.gnu.org/gnu/patch/patch-2.7.6.tar.xz
RUN apk add xz
RUN tar xfv patch-2.7.6.tar.xz
WORKDIR /build/patch-2.7.6
RUN ./configure --prefix=/usr/local/
RUN make
RUN make install
RUN apk del alpine-sdk
RUN apk del xz
RUN apk del wget
RUN rm -rf /build
LABEL examples=layers
```

If you are doing this in your docker images, **You are doing it WRONG**.  
Lets build and inspect this image.

```shell
docker build --file=examples/layers/Dockerfile.justwrong -t jamesbrink/layers/justwrong .
```

You can verify the image works and containers our downloaded version of patch:
```shell
docker run -i -t jamesbrink/layers/justwrong patch --version
```

Once build completes you should see the new docker image, since we added a label we can list it like so:
```shell
docker images --filter=label=examples=layers
```

You will see the image is ~200MB uncompressed. Now lets inspect the image a bit more with the `history` command.  

Running the history command will show you each layer with its size.
```shell
docker history jamesbrink/layers/justwrong:latest
```

![image history](./images/layers-wrong-history.png "Image history for justwrong.")

You can basically sum the sizes in the the `size` column and calculate the final image size just the same. **The take away here is that removing files, packages etc in later steps does not remove them from the final image's size**

### The better way

Now that we have built a bloated ass version Docker image containing patch, lets build it again but more efficiently.

```Dockerfile
FROM alpine:3.10
RUN set -xe; \
    apk add --no-cache --virtual .build-deps \
        alpine-sdk \
        wget \
        xz; \
    mkdir -p /build; \
    cd /build; \
    wget http://ftp.gnu.org/gnu/patch/patch-2.7.6.tar.xz; \
    tar xfv patch-2.7.6.tar.xz; \
    cd /build/patch-2.7.6; \
    ./configure --prefix=/usr/local/; \
    make; \
    make install; \
    cd /; \
    rm -rf /build; \
    apk del .build-deps;

LABEL examples=layers
```

Given the above Dockerfile lets build it again like so:
```shell
docker build --file=examples/layers/Dockerfile.better -t jamesbrink/layers/better .
```

And again let's verify GNU patch is working:
```shell
docker run -i -t jamesbrink/layers/better patch --version
```

Lets look at the history for this new image.
```shell
docker history jamesbrink/layers/better:latest
```

![image history](./images/layers-better-history.png "Image history for better.")

Now lets compare the sizes between each of these images:
```shell
docker images --filter=label=examples=layers
```

You will see the new image is only ~ 6.54MB, this is a drastic difference from the original 200MB image. Feel free to inspect the history which is now down from 19 layers to 5.

![image sizes](./images/layers-diff.png "Difference between right and wrong.")

# Base Images

The first thing to consider when building a docker image is which base image to start with. 
Nine times out of ten I would say use Alpine. I say this because its very small and generally more secure. 
I have found the Alpine images tend to be patched for CVEs quicker than most other base images. 

## Always use a tagged image

It is highly recommended to always use a tagged image, in this case we will use `alpine:3.10`. This keeps builds
consistent, you should not have any surprises when you try to re-build the image 6 months from now as you might if you used `latest` (which is the default when tag name is omitted)

```Dockerfile
FROM alpine:3.10
```



