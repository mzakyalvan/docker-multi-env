# README

## Introduction

This project is proof of concept on building docker image for multiple environment using single `Dockerfile`. 

```dockerfile
ARG BUILD_ENV=local

FROM maven:3.6.3-jdk-11 AS maven

## Build in local machine
FROM maven AS build-local
COPY ./target/docker-multi-env-*-SNAPSHOT.jar /build/application.jar

## Build in pegasus environment
FROM maven AS build-develop
#COPY settings.xml /root/.m2/settings.xml
COPY . /sources
WORKDIR /build
RUN mvn -f /sources/pom.xml clean install
RUN cp /sources/target/docker-multi-env-*-SNAPSHOT.jar ./application.jar

## Build in staging or release environment
FROM maven AS build-staging
#COPY settings.xml /root/.m2/settings.xml
COPY . /sources
WORKDIR /build
RUN mvn -f /sources/pom.xml -P docker -B clean release:clean release:prepare release:perform
RUN cp $(ls -d /sources/target/checkout/docker-multi-env/target/* | grep '^.*/docker-multi-env-[0-9]*\.[0-9]*\.[0-9]*-[0-9]*\.jar$') ./application.jar

## Extract built jar file into layers
FROM build-${BUILD_ENV} AS extractor
WORKDIR /build/layers
RUN java -Djarmode=layertools -jar /build/application.jar extract

## Create final docker image.
FROM asia-southeast1-docker.pkg.dev/tk-dev-micro/base-image/distroless-java11
WORKDIR /app
COPY --from=extractor build/layers/dependencies/ ./
COPY --from=extractor build/layers/spring-boot-loader ./
COPY --from=extractor build/layers/snapshot-dependencies/ ./
COPY --from=extractor build/layers/application/ ./
ENTRYPOINT ["java", "org.springframework.boot.loader.JarLauncher"]
```

## Building Image

## Build in Local Environment

From project root directory, execute following command

```shell script
$ mvn clean package
```

If BuildKit feature enabled in docker daemon, we could use following command, and ignore next command.

```shell script
$ mvn clean package docker:build
```

Or by enabling BuildKit for current session

```shell script
$ DOCKER_BUILDKIT=1 docker build -t local .
```

Or using kaniko executor.

> Default BUILD_ENV build args is local, so no need to set it explicitly.

```shell script
$ docker run \
    -v $HOME/.m2/repository:/root/.m2/repository \
    -v `pwd`:/workspace \
    gcr.io/kaniko-project/executor:latest \
    --dockerfile /workspace/Dockerfile \
    --destination "docker-multi-environment:local" \
    --skip-unused-stages=true \
    --no-push \
    --context dir:///workspace/
```

### Simulate Build in Develop Environment

```shell script
$ docker run \
    -v $HOME/.m2/repository:/root/.m2/repository \
    -v `pwd`:/workspace \
    gcr.io/kaniko-project/executor:latest \
    --dockerfile /workspace/Dockerfile \
    --destination "docker-multi-environment:latest" \
    --build-arg="BUILD_ENV=develop" \
    --skip-unused-stages=true \
    --no-push \
    --context dir:///workspace/
```

## Todo
- Enable BuildKit in maven docker plugin (Set host environment variable `DOCKER_BUILDKIT=1`).