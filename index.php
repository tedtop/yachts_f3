<?php
require 'vendor/autoload.php';
$f3 = \Base::instance();

if ($_SERVER['SERVER_NAME'] == 'charterboats.com') {
    $db = new DB\SQL(
        'mysql:host=localhost;port=3306;dbname=charscom_yachts',
        'charscom_yachts',
        'charscom_yachts'
    );
} else {
    $db = new DB\SQL(
        'mysql:host=localhost;port=3306;dbname=yachts_ci',
        'root',
        'root'
    );
}

$f3->redirect('GET /', '/listings');

$f3->route(
    'GET /listings',
    function ($f3) use ($db) {
        $result = $db->exec('SELECT nice_name FROM location ORDER BY nice_name');
        $locations = array_map(function ($el) {
            return $el['nice_name'];
        }, $result);
        $f3->set('locations', $locations);

        $listings = $db->exec('SELECT * FROM charterindex_listing ORDER BY RAND() LIMIT 10');
        $f3->set('listings', $listings);

        echo Template::instance()->render('templates/panagea_list.phtml');
    }
);

$f3->route(
    'GET /listings/@id',
    function ($f3) use ($db) {
        $listing = new DB\SQL\Mapper($db, 'charterindex_listing');
        $listing->load(['id=?', $f3->get('PARAMS.id')]);
        $f3->set('ESCAPE', FALSE);
        $f3->set('listing', $listing);

        echo View::instance()->render('templates/panagea_detail.phtml');
    }
);

$f3->route(
    'GET /debug/@id',
    function ($f3) use ($db) {
        $listing = new DB\SQL\Mapper($db, 'charterindex_listing');
        $listing->load(['id=?', $f3->get('PARAMS.id')]);
        $f3->set('result', $listing);

        echo View::instance()->render('templates/debug.phtml');
    }
);

$f3->route(
    'GET /locations',
    function ($f3) use ($db) {
        $f3->set('locations', $db->exec('SELECT * FROM location ORDER BY nice_name'));
        echo Template::instance()->render('templates/locations.phtml');
    }
);

$f3->route(
    'GET /locations/@name',
    function ($f3) use ($db) {

        $sql = 'SELECT name FROM charterindex_listing
                JOIN listing_location ON listing_location.listing_id = charterindex_listing.id
                JOIN location on location.id = listing_location.location_id
                WHERE location.key = "' . $f3->get('PARAMS.name') . '"';

        $listings = $db->exec($sql);
        // echo count($listings) . " listings";
        $f3->set('count', count($listings));
        $f3->set('listings', $db->exec($sql));
        echo Template::instance()->render('templates/locations_listings.phtml');
    }
);

$f3->route(
    'GET /locations/{name}/listings',
    function ($f3) {
        $json = file_get_contents('assets/data/apollo_listings.json');
        $yachts = json_decode($json, false);

        $f3->set('yachts', $yachts);
        echo View::instance()->render('templates/paginated.phtml');
    }
);

/* === APOLLO === */
$f3->route(
    'GET /location/@location',
    function ($f3) {
        $json = file_get_contents('assets/data/apollo_listings.json');
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

$f3->route(
    'GET /apollo/listings',
    function ($f3) use ($db) {
        $json = file_get_contents('assets/data/apollo_listings.json');
        $yachts = json_decode($json, false);

        $f3->set('yachts', $yachts);
        echo View::instance()->render('templates/apollo_list.phtml');
    }
);

$f3->route(
    'GET /apollo/listings/@id',
    function ($f3) {
        $json = file_get_contents('assets/data/apollo_listings.json');
        $yachts = json_decode($json, false);

        $f3->set('yacht', $yachts[$f3->get('PARAMS.id') - 1]);
        echo View::instance()->render('templates/apollo_single.phtml');
    }
);

$f3->run();
