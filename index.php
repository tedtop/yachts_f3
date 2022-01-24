<?php
require 'vendor/autoload.php';
$f3 = \Base::instance();

$f3->route('GET /',
    function($f3) {
        $json = file_get_contents('assets/apollo_listings.json');
        $yachts = json_decode($json, false);

        $f3->set('yachts', $yachts);
        echo View::instance()->render('templates/paginated.phtml');
        
        // echo "<pre>";
        // print_r($yachts);
        // echo "</pre>";
    }
);

$f3->route('GET /location/@location',
    function($f3) {
        $json = file_get_contents('assets/apollo_listings.json');
        $yachts = json_decode($json, false);

        $filteredYachts = array();
        foreach ($yachts as $yacht) {
            if (str_contains($yacht->operating_in, $f3->get('PARAMS.location'))) {
                array_push($filteredYachts, $yacht);
            }
        }

        $f3->set('yachts', $filteredYachts);
        echo View::instance()->render('templates/paginated.phtml');
    }
);

$f3->route('GET /yacht/@id',
    function($f3) {
        $json = file_get_contents('assets/apollo_listings.json');
        $yachts = json_decode($json, false);

        $f3->set('yacht', $yachts[$f3->get('PARAMS.id') - 1]);
        echo View::instance()->render('templates/single.phtml');
    }
);

$f3->run();
