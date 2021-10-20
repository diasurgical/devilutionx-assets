#!/bin/bash
cd assets
find * -type f -exec smpq -M 1 -C PKWARE -c ../fonts.mpq {} +
cd ..

cd pl
find * -type f -exec smpq -M 1 -C PKWARE -c ../pl.mpq {} +
cd ..
