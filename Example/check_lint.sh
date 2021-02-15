#!/bin/sh

if [ -s oclint.xml ]
then
    cat oclint.xml
    exit 1
else
    echo "linting success"
    exit 0
fi
