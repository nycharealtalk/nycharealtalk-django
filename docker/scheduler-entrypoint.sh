#!/bin/sh
# Cron doesn't inherit the container's environment, so write it out first.
env >> /etc/environment
exec cron -f
