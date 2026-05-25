use derive_more::Display;
use derive_more::FromStr;
use regex::Regex;
use std::str::FromStr;

#[derive(Debug, Display)]
#[display("GpsTracking (prn={prn}, el={el}, zz={az}, ss={ss})")]
struct GpsTracking {
    prn: u32,
    el: u32,
    az: u32,
    ss: u32,
}

#[derive(Debug, Display)]
#[display("GpsNotTracking (prn={prn}, el={el}, zz={az})")]
struct GpsNotTracking {
    prn: u32,
    el: u32,
    az: u32,
}

#[derive(Debug, Display, FromStr)]
enum HealthState {
    Ok,
    Fail,
    Unknown,
}

/*

impl HealthState {
    fn from_str(state: &str) -> Self {
        match state {
            "OK" => HealthState::Ok,
            "FAIL" => HealthState::Fail,
            _ => HealthState::Unknown,
        }
    }
}
*/

#[derive(Debug, Display)]
#[display(
    "HealthMonitor (self_test={self_test}, int_pwr={int_pwr}, oven_pwr={oven_pwr}, ocxo={ocxo} efc={efc} gps_rcv={gps_rcv})"
)]
struct HealthMonitor {
    self_test: HealthState,
    int_pwr: HealthState,
    oven_pwr: HealthState,
    ocxo: HealthState,
    efc: HealthState,
    gps_rcv: HealthState,
}

#[derive(Debug, Display)]
enum SmartClockMode {
    LockedToGps,
    Recovery,
    Holdover,
    PowerUp,
    Unknown,
}

#[derive(Debug)]
struct ParseSmartClockModeError;

impl FromStr for SmartClockMode {
    type Err = ParseSmartClockModeError;

    fn from_str(mode: &str) -> Result<Self, Self::Err> {
        match mode {
            "Locked to GPS" => Ok(SmartClockMode::LockedToGps),
            "Recovery" => Ok(SmartClockMode::Recovery),
            "Holdover" => Ok(SmartClockMode::Holdover),
            "Power-up" => Ok(SmartClockMode::PowerUp),
            _ => Err(ParseSmartClockModeError),
        }
    }
}

fn main() {
    let input = r#"
scpi > :SYSTEM:STATUS?
------------------------------- Receiver Status -------------------------------
SYNCHRONIZATION ............................................. [ Outputs Valid ]
SmartClock Mode ___________________________   Reference Outputs _______________
   Recovery                                   1PPS TI +8.0 ns relative to GPS
>> Locked to GPS                              TFOM     3             FFOM     0
   Holdover                                   HOLD THR 1.000 us
   Power-up                                   Holdover Uncertainty ____________
                                              Predict  12.7 us/initial 24 hrs
                                                
ACQUISITION ................................................ [ GPS 1PPS Valid ]
Tracking: 7 ____   Not Tracking: 1 ________   Time ____________________________
PRN  El  Az   SS   PRN  El  Az                UTC      03:13:42     08 Jun 2005
  5  62  95  167   *28  10 274                GPS 1PPS Synchronized to UTC
 11  17  54   18                              ANT DLY  0 ns
 12  31 163   80                              Position ________________________
 18  35 255  107                              MODE     Hold
 20  36  50  116                              
 25  59 206  141                              LAT      N  37:22:30.277
 29  61 332  138                              LON      W 122:05:34.816
                                              HGT               +43.51 m  (MSL)
ELEV MASK 10 deg   *attempting to track       
HEALTH MONITOR ......................................................... [ OK ]
Self Test: OK    Int Pwr: OK   Oven Pwr: OK   OCXO: OK   EFC: OK   GPS Rcv: OK 
scpi >
"#;

    // Extract SmartClock Mode
    let mode_re = Regex::new(r">>\s*(Locked to GPS|Recovery|Holdover|Power-up)").unwrap();
    let smartclock_mode = mode_re.captures(input).unwrap()[1]
        .parse()
        .unwrap_or(SmartClockMode::Unknown);

    // Extract GPS tracking PRNs
    let tracking_re = Regex::new(r"(?m)^[ \t]+(\d+)[ \t]+(\d+)[ \t]+(\d+)[ \t]+(\d+)").unwrap();
    let mut tracking_prns: Vec<GpsTracking> = Vec::new();
    for captures in tracking_re.captures_iter(input) {
        let prn = captures[1].parse::<u32>().unwrap();
        let el = captures[2].parse::<u32>().unwrap();
        let az = captures[3].parse::<u32>().unwrap();
        let ss = captures[4].parse::<u32>().unwrap();
        tracking_prns.push(GpsTracking { prn, el, az, ss });
    }

    // Extract GPS not tracking PRNs
    //
    // This is not right ... we might not have any tracked SVs and
    // what's more trying to parse this with regex'es is dumb.
    let not_tracking_re = Regex::new(
        r"(?m)^[ \t]+\d+[ \t]+\d+[ \t]+\d+[ \t]+\d+[ \t]*\*?[ \t]*(\d+)[ \t]+(\d+)[ \t]+(\d+)",
    )
    .unwrap();
    let mut not_tracking_prns: Vec<GpsNotTracking> = Vec::new();
    for captures in not_tracking_re.captures_iter(input) {
        let prn = captures[1].parse::<u32>().unwrap();
        let el = captures[2].parse::<u32>().unwrap();
        let az = captures[3].parse::<u32>().unwrap();
        not_tracking_prns.push(GpsNotTracking { prn, el, az });
    }

    // Extract Health Monitor states
    let health_monitor_re = Regex::new(
        r"(?m)^Self Test:[ \t]+(\w+)[ \t]+Int Pwr:[ \t]+(\w+)[ \t]+Oven Pwr:[ \t]+(\w+)[ \t]+OCXO:[ \t]+(\w+)[ \t]+EFC:[ \t]+(\w+)[ \t]+GPS Rcv:[ \t]+(\w+)",
    )
    .unwrap();
    let health_monitor = if let Some(captures) = health_monitor_re.captures(input) {
        HealthMonitor {
            self_test: captures[1].parse().unwrap(),
            int_pwr: captures[2].parse().unwrap(),
            oven_pwr: captures[3].parse().unwrap(),
            ocxo: captures[4].parse().unwrap(),
            efc: captures[5].parse().unwrap(),
            gps_rcv: captures[6].parse().unwrap(),
        }
    } else {
        HealthMonitor {
            self_test: HealthState::Unknown,
            int_pwr: HealthState::Unknown,
            oven_pwr: HealthState::Unknown,
            ocxo: HealthState::Unknown,
            efc: HealthState::Unknown,
            gps_rcv: HealthState::Unknown,
        }
    };

    println!("SmartClock Mode: {smartclock_mode:#?}");
    println!(
        "Tracking PRNs (n={0}): {1:#?}",
        tracking_prns.len(),
        tracking_prns
    );
    println!(
        "Not Tracking PRNs (n={0}): {1:#?})",
        not_tracking_prns.len(),
        not_tracking_prns
    );
    println!("Health Monitor: {health_monitor:#?}");
}
