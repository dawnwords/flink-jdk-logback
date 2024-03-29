###############################################################################
#  Licensed to the Apache Software Foundation (ASF) under one
#  or more contributor license agreements.  See the NOTICE file
#  distributed with this work for additional information
#  regarding copyright ownership.  The ASF licenses this file
#  to you under the Apache License, Version 2.0 (the
#  "License"); you may not use this file except in compliance
#  with the License.  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
# limitations under the License.
###############################################################################

## Use jdk as base image
FROM airdock/oraclejdk:1.8

# Install dependencies
RUN set -ex; \
  apt-get update; \
  apt-get -y install libsnappy-dev gettext-base wget unzip; \
  rm -rf /var/lib/apt/lists/*

# Grab gosu for easy step-down from root
ENV GOSU_VERSION 1.11
RUN set -ex; \
  wget -nv -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)"; \
  wget -nv -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc"; \
  export GNUPGHOME="$(mktemp -d)"; \
  for server in ha.pool.sks-keyservers.net $(shuf -e \
                          hkp://p80.pool.sks-keyservers.net:80 \
                          keyserver.ubuntu.com \
                          hkp://keyserver.ubuntu.com:80 \
                          pgp.mit.edu) ; do \
      gpg --batch --keyserver "$server" --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 && break || : ; \
  done && \
  gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
  rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc; \
  chmod +x /usr/local/bin/gosu; \
  gosu nobody true

# Configure Flink version
ENV FLINK_TGZ_URL=https://www.apache.org/dyn/closer.cgi?action=download&filename=flink/flink-1.14.0/flink-1.14.0-bin-scala_2.12.tgz \
    FLINK_ASC_URL=https://www.apache.org/dist/flink/flink-1.14.0/flink-1.14.0-bin-scala_2.12.tgz.asc \
    GPG_KEY=31D2DD10BFC15A2D \
    CHECK_GPG=true

# Prepare environment
ENV FLINK_HOME=/opt/flink
ENV PATH=$FLINK_HOME/bin:$PATH
RUN groupadd --system --gid=9999 flink && \
    useradd --system --home-dir $FLINK_HOME --uid=9999 --gid=flink flink
WORKDIR $FLINK_HOME

# Install Flink
RUN set -ex; \
  wget -nv -O flink.tgz "$FLINK_TGZ_URL"; \
  \
  if [ "$CHECK_GPG" = "true" ]; then \
    wget -nv -O flink.tgz.asc "$FLINK_ASC_URL"; \
    export GNUPGHOME="$(mktemp -d)"; \
    for server in ha.pool.sks-keyservers.net $(shuf -e \
                            hkp://p80.pool.sks-keyservers.net:80 \
                            keyserver.ubuntu.com \
                            hkp://keyserver.ubuntu.com:80 \
                            pgp.mit.edu) ; do \
        gpg --batch --keyserver "$server" --recv-keys "$GPG_KEY" && break || : ; \
    done && \
    gpg --batch --verify flink.tgz.asc flink.tgz; \
    rm -rf "$GNUPGHOME" flink.tgz.asc; \
  fi; \
  \
  tar -xf flink.tgz --strip-components=1; \
  rm flink.tgz; \
  \
  chown -R flink:flink .;

# Configure container
COPY docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]
EXPOSE 6123 8081
CMD ["help"]

## Add logback depenecies

ARG LOGBACK_VERSION=1.2.3
ARG SLF4J_VERSION=1.7.25

RUN rm /opt/flink/conf/log4j* && \
  rm -f /opt/flink/lib/*log4j* && \
  mkdir -p /opt/flink/tmp-dir && \
  mkdir -p /opt/flink/state-backend && \
  chown -R flink:flink /opt/flink/tmp-dir && \
  chown -R flink:flink /opt/flink/state-backend && \
  wget --quiet https://repo1.maven.org/maven2/ch/qos/logback/logback-classic/${LOGBACK_VERSION}/logback-classic-${LOGBACK_VERSION}.jar -O /opt/flink/lib/logback-classic-${LOGBACK_VERSION}.jar && \
  wget --quiet https://repo1.maven.org/maven2/ch/qos/logback/logback-core/${LOGBACK_VERSION}/logback-core-${LOGBACK_VERSION}.jar -O /opt/flink/lib/logback-core-${LOGBACK_VERSION}.jar && \
  wget --quiet https://repo1.maven.org/maven2/org/slf4j/log4j-over-slf4j/${SLF4J_VERSION}/log4j-over-slf4j-${SLF4J_VERSION}.jar -O /opt/flink/lib/log4j-over-slf4j-${SLF4J_VERSION}.jar && \
  wget --quiet https://arthas.aliyun.com/download/latest_version?mirror=aliyun -O /opt/flink/arthas-bin.zip && \
  wget https://arthas.aliyun.com/download/latest_version?mirror=aliyun -O /opt/flink/arthas-bin.zip && \
  unzip /opt/flink/arthas-bin.zip -d /opt/flink/arthas-bin && \
  rm -f /opt/flink/arthas-bin.zip


ADD logback.xml /opt/flink/conf/logback-console.xml

VOLUME ["/opt/flink/tmp-dir", "/opt/flink/state-backend"]
