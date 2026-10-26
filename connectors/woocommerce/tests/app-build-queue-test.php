<?php
/** Run the shared runtime contracts against the shipped connector exporter. */
define( 'MOBISHOP_EXPORTER_SOURCE', dirname( __DIR__ ) . '/source/includes/class-mobishop-app-exporter.php' );
require dirname( __DIR__, 3 ) . '/mobishop/tests/app-build-queue-test.php';
