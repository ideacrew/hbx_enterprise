docker build --build-arg BUNDLER_VERSION_OVERRIDE='1.17.3' \
             -f .docker/production/Dockerfile --target app -t $2:$1 .
docker push $2:$1

