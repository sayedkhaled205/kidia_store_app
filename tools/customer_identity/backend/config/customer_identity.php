<?php
// Deployment must explicitly bind each authorized store to its Auth project, not its push project.
return [
    'enabled' => false,
    'auth_projects' => [],
];
