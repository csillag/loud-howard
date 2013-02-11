#!/bin/sh

make -C public/__lh__/coffee
make -C public/__lh__/lib/magic_range
coffee server.coffee
