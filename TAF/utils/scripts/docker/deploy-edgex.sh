#!/bin/sh

TEST_STRATEGY=${1:-}
APPSERVICE=${2:-}
CONF_DIR=/custom-config

if [ "$TEST_STRATEGY" = "PerformanceMetrics" ]; then
  docker run --rm -v ${WORK_DIR}:${WORK_DIR}:rw,z -w ${WORK_DIR} -v /var/run/docker.sock:/var/run/docker.sock \
          --env WORK_DIR=${WORK_DIR} --env PROFILE=${PROFILE} --security-opt label:disable \
          --env-file ${WORK_DIR}/TAF/utils/scripts/docker/common-taf.env \
          ${COMPOSE_IMAGE} -f "${WORK_DIR}/TAF/utils/scripts/docker/docker-compose${APPSERVICE}.yml" up -d
else
  for PROFILE in device-virtual device-modbus; do
    docker run --rm -v ${WORK_DIR}:${WORK_DIR}:rw,z -w ${WORK_DIR} -v /var/run/docker.sock:/var/run/docker.sock \
           --security-opt label:disable --env CONF_DIR=${CONF_DIR} --env WORK_DIR=${WORK_DIR} ${COMPOSE_IMAGE} -f \
           "${WORK_DIR}/TAF/utils/scripts/docker/docker-compose.yml" up --no-start --no-deps ${PROFILE}

    # copy device service default configuration in the res to TAF/config/{service}/res
    docker cp edgex-${PROFILE}:/res/configuration.toml ${WORK_DIR}/TAF/config/${PROFILE}
    sed -i '/DevicesDir/d' ${WORK_DIR}/TAF/config/${PROFILE}/configuration.toml
    sed -i "s/ProfilesDir.*/ProfilesDir = '\\$CONF_DIR'/g" ${WORK_DIR}/TAF/config/${PROFILE}/configuration.toml

  done

  if [ "$TEST_STRATEGY" = "MQTTMessageBus" ]; then
    docker run --rm -v ${WORK_DIR}:${WORK_DIR}:rw,z -w ${WORK_DIR} -v /var/run/docker.sock:/var/run/docker.sock \
          --env-file ${WORK_DIR}/TAF/utils/scripts/docker/common-taf.env \
          --env WORK_DIR=${WORK_DIR} --env CONF_DIR=${CONF_DIR} --security-opt label:disable ${COMPOSE_IMAGE} \
          -f "${WORK_DIR}/TAF/utils/scripts/docker/docker-compose-mqtt-bus.yml" up -d
  else
    docker run --rm -v ${WORK_DIR}:${WORK_DIR}:rw,z -w ${WORK_DIR} -v /var/run/docker.sock:/var/run/docker.sock \
          --env-file ${WORK_DIR}/TAF/utils/scripts/docker/common-taf.env \
          --env WORK_DIR=${WORK_DIR} --env CONF_DIR=${CONF_DIR} --security-opt label:disable ${COMPOSE_IMAGE} \
          -f "${WORK_DIR}/TAF/utils/scripts/docker/docker-compose.yml" up -d
  fi
fi

# Waiting for all services startup
sleep 5

if [ "$SECURITY_SERVICE_NEEDED" = "true" ]; then
  for i in $(seq 1 12);
  do
    echo "Waiting for proxy setup is ready. Loop sleep times:${i}"
    result=$(docker ps -a | grep edgex-security-proxy-setup | grep Up)
    if [ -n "$result" ]; then
      sleep 5
    else
      echo "Proxy Setup is ready."
      break
    fi
  done
fi
