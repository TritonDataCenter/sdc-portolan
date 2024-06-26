<!--
    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at http://mozilla.org/MPL/2.0/.
-->

<!--
    Copyright 2019 Joyent, Inc.
    Copyright 2024 MNX Cloud, Inc.
-->

# sdc-portolan

This repository is part of the Triton Data Center project. See the [contribution
guidelines](https://github.com/TritonDataCenter/triton/blob/master/CONTRIBUTING.md)
and general documentation at the main
[Triton project](https://github.com/TritonDataCenter/triton) page.

Portolan is the service for looking up VXLAN underlay devices.


# Development

To run style and lint checks:

    make check

To run all checks and tests:

    make prepush


# Testing

## Unit tests

To run all tests:

    make test

To run an individual test:

    node ./test/unit/testname.test.js


## Integration tests

To run an individual test:

    node ./test/integration/testname.test.js

If you're not in the portolan zone, you can run an individual test by
setting the `MORAY_HOST` environment variable:

    MORAY_HOST=10.99.99.17 node ./test/integration/backend.test.js
