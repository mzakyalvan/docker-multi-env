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