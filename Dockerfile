# The public half of the server's deploy: ./shipserver copies this file, start, and the source
# encrypted with SOURCE_PASSPHRASE into the public repo Back4App builds from. Back4App hands its
# app settings to the build as build arguments, so the passphrase never sits in the repo.

FROM eclipse-temurin:21-jdk AS build
RUN apt-get update && apt-get install -y --no-install-recommends gnupg && rm -rf /var/lib/apt/lists/*
WORKDIR /src
COPY server.tar.gz.gpg /tmp/
ARG SOURCE_PASSPHRASE
# Decrypted to a file, never piped into tar: gpg reports a tampered or truncated file only once
# its output has ended, and tar would already have accepted it.
RUN test -n "$SOURCE_PASSPHRASE" || { echo "SOURCE_PASSPHRASE did not reach the build" >&2; exit 1; }; \
    printf %s "$SOURCE_PASSPHRASE" | gpg --batch --quiet --passphrase-fd 0 -o /tmp/src.tar.gz -d /tmp/server.tar.gz.gpg \
    && tar -xzf /tmp/src.tar.gz \
    && ./gradlew --no-daemon -PserverOnly :server:installDist

FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /src/server/build/install/server ./
COPY start ./
# Back4App terminates TLS in front, so listening on every address is safe here. The JAVA_OPTS are
# the ones a full two-phone game was measured under in the free plan's 256 MB (notes/runbook.md).
ENV BIND_ADDRESS=0.0.0.0 \
    PORT=8080 \
    JAVA_OPTS="-XX:MaxRAMPercentage=50 -XX:+UseSerialGC -XX:MaxMetaspaceSize=100m -Xss256k -XX:ReservedCodeCacheSize=32m -XX:TieredStopAtLevel=1"
EXPOSE 8080
CMD ["./start"]
