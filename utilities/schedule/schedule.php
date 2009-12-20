<?php
 
//Avoid unstubbing $wgParser on setHook() too early on modern (1.12+) MW versions, as per r35980
if ( defined( 'MW_SUPPORTS_PARSERFIRSTCALLINIT' ) ) {
    $wgHooks['ParserFirstCallInit'][] = 'efScheduleInit';
} else { // Otherwise do things the old fashioned way
    $wgExtensionFunctions[] = 'efScheduleInit';
}

$wgAutoloadClasses['Schedule'] = dirname( __FILE__ ) . "/schedule.body.php";

function efScheduleInit() {
    new Schedule;
    return true;
}