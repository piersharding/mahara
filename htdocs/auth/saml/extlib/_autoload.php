<?php

spl_autoload_register(
    function($classname) {
        $classpath = explode('_', $classname);
        if ($classpath[0] != 'SimpleSAML') {
            $classpath = explode('\\', $classname);
            if ($classpath[0] != 'SimpleSAML') {
                return;
            }
        }
        $filepath = get_config('docroot') .'auth/saml/extlib/simplesamlphp/lib/' . implode('/', $classpath) . '.php';
        if (file_exists($filepath)) {
            require_once($filepath);
        }
    }
);

spl_autoload_register(
    function($classname) {
       $classpath = explode('_', $classname);
        if ($classpath[0] != 'sspmod') {
            $classpath = explode('\\', $classname);
            if ($classpath[0] != 'sspmod') {
                return;
            }
        }
        array_shift($classpath);
        $module = array_shift($classpath);
        $filepath = get_config('docroot') .'auth/saml/extlib/simplesamlphp/modules/$module/lib/' . implode('/', $classpath) . '.php';
        if (file_exists($filepath)) {
            require_once($filepath);
        }
    }
);
