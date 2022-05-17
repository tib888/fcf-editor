#[macro_use]
extern crate clap;
extern crate actix_rt;
extern crate actix_web;
extern crate pest;
#[macro_use]
extern crate pest_derive;
mod fcf;
mod parser;

use fcf::*;
use parser::*;

use std::fs;
use std::str;
//use std::cell::Cell;
use serde::{Deserialize, Serialize};
//use actix_rt;
//use json::JsonValue;
use actix_web::{web, App, HttpResponse, HttpServer, Responder};
use clap::App as ClapApp;
use std::sync::{Arc, RwLock};

#[derive(Debug, Serialize, Deserialize)]
pub enum EditFCF {
    ChangeToleranceValue(usize, String),
    ChangeDatumUse(Vec<usize>, String),
}

struct AppState {
    pub full_fcf: Arc<RwLock<FullFcf>>,
}

#[actix_rt::main]
async fn main() -> std::io::Result<()> {
    let default_address = "localhost:7878";
    let matches = ClapApp::new("FCFeditor backend (server)")
        .version(crate_version!())
        .author("Tibor Prokai")
        .arg(
            clap::Arg::with_name("address")
                .help(&(String::from("Sets an custom address the default is ") + default_address))
                .index(1),
        )
        .get_matches();

    let address = matches.value_of("address").unwrap_or(default_address);

    println!(
        "While this server runing, open http://{} in a browser and lets play with the FCF editor!",
        address
    );

    let state = Arc::new(RwLock::new(init()));

    HttpServer::new(move || {
        App::new()
            // enable logger  .wrap(middleware::Logger::default())
            //.data(web::JsonConfig::default().limit(65536)) // <- limit size of the payload (global configuration)
            .data(AppState {
                full_fcf: state.clone(),
            })
            .route("/", web::get().to(index))
            .route("/api/v1/GetFCF", web::get().to(get_fcf))
            .route("/api/v1/EditFCF", web::post().to(edit_fcf))
            .route("/api/v1/TypeFCF", web::post().to(type_fcf))
    })
    .bind(address)?
    .run()
    .await
}

async fn index() -> impl Responder {
    HttpResponse::Ok().body(
        fs::read_to_string(r"T:\Private_tibi\elm\frontends\fcf.html")
            .unwrap_or(include_str!(r"../../frontends/fcf.html").to_string())
            .to_string(),
    )
}

fn change_datum_use(
    mut original: Vec<DatumUsage>,
    path: &[usize],
    new_value: String,
) -> Vec<DatumUsage> {
    if path.len() == 1 {
        if path[0] < original.len() {
            if let DatumReference::Single(d) = original[path[0]].datum.clone() {
                original[path[0]].datum = DatumReference::Single(Datum {
                    label: new_value,
                    ..d
                });
            }
        }
    } else if path.len() > 1 {
        if path[0] < original.len() {
            if let DatumReference::Compound(c) = original[path[0]].datum.clone() {
                original[path[0]].datum =
                    DatumReference::Compound(change_datum_use(c, &path[1..path.len()], new_value));
            }
        }
    }
    original
}

//#[post("/api/v1/TypeFCF")]
async fn type_fcf(data: web::Data<AppState>, txt: web::Json<String>) -> impl Responder {
    //println!("{:?}", params);
    let mut full_fcf = data.full_fcf.write().unwrap();
    match from_human_readable(&txt) {
        Ok(tiers) => { 
            full_fcf.human_readable = to_human_readable(&tiers);
            full_fcf.tiers = tiers; 
        },
        Err(e) => full_fcf.human_readable = e,
    }
    HttpResponse::Ok().json(&*full_fcf)
}


//#[post("/api/v1/EditFCF")]
async fn edit_fcf(data: web::Data<AppState>, params: web::Json<EditFCF>) -> impl Responder {
    //println!("{:?}", params);
    let mut full_fcf = data.full_fcf.write().unwrap();
    match params.0 {
        EditFCF::ChangeToleranceValue(tier_index, new_value) => full_fcf.tiers[tier_index].usl = new_value,
        EditFCF::ChangeDatumUse(path, new_value) => {
            for i in 0..full_fcf.tiers.len() {
                //edit all tiers simultaneously
                full_fcf.tiers[i].drf = change_datum_use(
                    full_fcf.tiers[i].drf.clone(),
                    &path[1..path.len()],
                    new_value.to_uppercase(),
                );
            }
        }
    };
    full_fcf.human_readable = to_human_readable(&full_fcf.tiers);
    HttpResponse::Ok().json(&*full_fcf)
}

//#[get("/api/v1/GetFCF")]
async fn get_fcf(data: web::Data<AppState>) -> impl Responder {
    let full_fcf = &(*data.full_fcf.read().unwrap());
    HttpResponse::Ok().json(full_fcf)
}

fn init() -> FullFcf {
    let tiers = from_human_readable(
        "[ Position | 0.1: MMC | ((A: MMC - B: MMC): SL - (C: MMC - D: MMC): SL) | E | F: LMC, SL ]\n[ Position | 0.05: MMC | ((A: MMC - B: MMC): SL - (C: MMC - D: MMC): SL) | E ]").unwrap_or_default();
/*
    let tiers = vec![
        Fcf {
            typ: GdtToleranceType::Position,
            usl: "0.1".to_owned(),
            modifiers: vec![Modifier::MMC],
            drf: vec![
                DatumUsage {
                    datum: DatumReference::Compound(vec![
                        DatumUsage {
                            datum: DatumReference::Compound(vec![
                                DatumUsage {
                                    datum: DatumReference::Single(Datum {
                                        label: "A".to_owned(),
                                    }),
                                    modifiers: vec![Modifier::MMC],
                                },
                                DatumUsage {
                                    datum: DatumReference::Single(Datum {
                                        label: "B".to_owned(),
                                    }),
                                    modifiers: vec![Modifier::MMC],
                                },
                            ]),
                            modifiers: vec![Modifier::SL],
                        },
                        DatumUsage {
                            datum: DatumReference::Compound(vec![
                                DatumUsage {
                                    datum: DatumReference::Single(Datum {
                                        label: "C".to_owned(),
                                    }),
                                    modifiers: vec![Modifier::MMC],
                                },
                                DatumUsage {
                                    datum: DatumReference::Single(Datum {
                                        label: "D".to_owned(),
                                    }),
                                    modifiers: vec![Modifier::MMC],
                                },
                            ]),
                            modifiers: vec![Modifier::SL],
                        },
                    ]),
                    modifiers: vec![],
                },
                DatumUsage {
                    datum: DatumReference::Single(Datum {
                        label: "E".to_owned(),
                    }),
                    modifiers: vec![],
                },
                DatumUsage {
                    datum: DatumReference::Single(Datum {
                        label: "F".to_owned(),
                    }),
                    modifiers: vec![Modifier::LMC],
                },
            ],
        },
        Fcf {
            typ: GdtToleranceType::Position,
            usl: "0.05".to_owned(),
            modifiers: vec![Modifier::MMC],
            drf: vec![
                DatumUsage {
                    datum: DatumReference::Compound(vec![
                        DatumUsage {
                            datum: DatumReference::Compound(vec![
                                DatumUsage {
                                    datum: DatumReference::Single(Datum {
                                        label: "A".to_owned(),
                                    }),
                                    modifiers: vec![Modifier::MMC],
                                },
                                DatumUsage {
                                    datum: DatumReference::Single(Datum {
                                        label: "B".to_owned(),
                                    }),
                                    modifiers: vec![Modifier::MMC],
                                },
                            ]),
                            modifiers: vec![Modifier::SL],
                        },
                        DatumUsage {
                            datum: DatumReference::Compound(vec![
                                DatumUsage {
                                    datum: DatumReference::Single(Datum {
                                        label: "C".to_owned(),
                                    }),
                                    modifiers: vec![Modifier::MMC],
                                },
                                DatumUsage {
                                    datum: DatumReference::Single(Datum {
                                        label: "D".to_owned(),
                                    }),
                                    modifiers: vec![Modifier::MMC],
                                },
                            ]),
                            modifiers: vec![Modifier::SL],
                        },
                    ]),
                    modifiers: vec![],
                },
                DatumUsage {
                    datum: DatumReference::Single(Datum {
                        label: "E".to_owned(),
                    }),
                    modifiers: vec![],
                },
            ],
        },
    ];
*/

    FullFcf 
    {
        human_readable: to_human_readable(&tiers),
        tiers: tiers
    }
}
