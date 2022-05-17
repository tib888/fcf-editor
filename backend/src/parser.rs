use crate::fcf::*;
use pest::Parser;

pub fn to_human_readable(tiers: &Vec<Fcf>) -> String {
    let mut result = String::new();
    for tier in tiers {
        result += &format!("{:?}\n", tier);
    }
    result
}

pub fn from_human_readable(input: &str) -> Result<Vec<Fcf>, String>
{
    match FCFParser::parse(Rule::input, input) {
        Ok(result) => process_tiers(result),
        Err(err) => Err(format!("{:?}", err)),
    }
}

#[derive(Parser)]
#[grammar = "FCF.pest"]
struct FCFParser;

/*
fn process_datum_usages(items: pest::iterators::Pairs<Rule>) -> Result<Vec<DatumUsage>, String>
{
    let mut sub = vec!();
    for item in items {
        sub.push(process_datum_usage(item.into_inner())?);
    }
    Ok(sub)
}

fn process_datum_reference(items: pest::iterators::Pairs<Rule>) -> Result<DatumReference, String>
{
    for item in items {
        match item.as_rule() {
            Rule::single => return Ok(DatumReference::Single(Datum { label : item.as_str().to_owned().to_uppercase() })),
            Rule::compound => return Ok(DatumReference::Compound(process_datum_usages(item.into_inner())?)),
            _ => return Err(format!("unexpected @ process_datum_reference: {:?}", item)),
        }
    }
    unreachable!()
}
*/
fn process_datum_box(items: pest::iterators::Pairs<Rule>) -> Result<DatumUsage, String>
{
    for item in items {
        match item.as_rule() {
            Rule::datum_uses => return process_datum_usages(item.into_inner()),
            _ => return Err(format!("unexpected @ process_datum_box: {:?}", item)),
        }
    }
    unreachable!()
}

fn process_datum_usages(items: pest::iterators::Pairs<Rule>) -> Result<DatumUsage, String>
{
    let mut first = None;
    let mut rest = None;
    let mut modifiers = vec!();

    for item in items {
        match item.as_rule() {
            Rule::modifier => modifiers.push(process_modifier(item.into_inner())?),
            Rule::datum_use => first = Some(process_datum_usage(item.into_inner())?),
            Rule::datum_uses => 
                if let Some(_) = first { 
                    rest = Some(process_datum_usages(item.into_inner())?)
                } else {
                    first = Some(process_datum_usages(item.into_inner())?)
                },
            _ => return Err(format!("unexpected @ process_datum_usage: {:?}", item)),
        }
    }

    if let Some(mut first) = first
    {
        //Collapse modifiers
        first.modifiers.append(&mut modifiers);
        modifiers.clear();
        
        if let Some(rest) = rest {
            //collapse if there were no modifiers
            match (&first.datum, first.modifiers.len(), &rest.datum, rest.modifiers.len()) {
                (DatumReference::Single(_), _, DatumReference::Compound(r), 0) => {
                        let mut datums = vec![first];
                        datums.append(&mut r.clone());
                        Ok(DatumUsage {
                            datum: DatumReference::Compound(datums),
                            modifiers: modifiers
                        })
                    },
                (DatumReference::Compound(f), 0, DatumReference::Single(_), _) => {
                        let mut datums = f.clone();
                        datums.push(rest);
                        Ok(DatumUsage {
                            datum: DatumReference::Compound(datums),
                            modifiers: modifiers
                        })
                    },
                (DatumReference::Compound(f), 0, DatumReference::Compound(r), 0) => {
                        let mut datums = f.clone();
                        datums.append(&mut r.clone());
                        Ok(DatumUsage {
                            datum: DatumReference::Compound(datums),
                            modifiers: modifiers
                        })
                    },
                _ => Ok(DatumUsage {
                    datum: DatumReference::Compound(vec![first, rest]),
                    modifiers: modifiers
                })
            }            
        } else {
            Ok(first)
        }
    } else {
        Err("Missing or invalid datum reference".to_owned())
    }
}

fn process_datum_usage(items: pest::iterators::Pairs<Rule>) -> Result<DatumUsage, String>
{
    let mut datum_reference = None;
    let mut modifiers = vec!();

    for item in items {
        match item.as_rule() {
            Rule::modifier => modifiers.push(process_modifier(item.into_inner())?),
            Rule::datum => datum_reference = Some(DatumReference::Single(Datum { label : item.as_str().to_owned().to_uppercase() })),
            _ => return Err(format!("unexpected @ process_datum_usage: {:?}", item)),
        }
    }

    if let Some(datum_reference) = datum_reference
    {
        Ok(DatumUsage {
            datum: datum_reference,
            modifiers: modifiers,
        })
    } else {
        Err("Missing or invalid datum reference".to_owned())
    }
}


fn process_usl(items: pest::iterators::Pairs<Rule>) -> Result<String, String>
{   
    Ok(items.as_str().to_owned())
}

fn process_modifier(items: pest::iterators::Pairs<Rule>) -> Result<Modifier, String>
{   
    for item in items {
        match item.as_rule() {
            Rule::mmc_modifier => return Ok(Modifier::MMC),
            Rule::lmc_modifier => return Ok(Modifier::LMC),
            Rule::sl_modifier => return Ok(Modifier::SL),
            _ => return Err(format!("unexpected modifier: {:?}", item)),
        }
    }
    unreachable!()
}

fn process_type(items: pest::iterators::Pairs<Rule>) -> Result<GdtToleranceType, String>
{   
    for item in items {
        match item.as_rule() {
            Rule::position_type => return Ok(GdtToleranceType::Position),
            Rule::profile_type => return Ok(GdtToleranceType::Profile),
            _ => return Err(format!("unexpected gdt type: {:?}", item)),
        }
    }
    unreachable!()
}

fn process_fcf_tier(items: pest::iterators::Pairs<Rule>) -> Result<Fcf, String>
{
    let mut typ = None;
    let mut usl = String::default();
    let mut modifiers = vec!();
    let mut drf = vec!();

    for item in items {
        match item.as_rule() {
            Rule::fcf_type => typ = Some(process_type(item.into_inner())?),
            Rule::usl => usl = process_usl(item.into_inner())?,
            Rule::modifier => modifiers.push(process_modifier(item.into_inner())?),
            Rule::drf_box => drf.push(process_datum_box(item.into_inner())?),
            _ => return Err(format!("Unexpected @ process_fcf_tier: {:?}", item)), 
        }
    }

    if let Some(typ) = typ {
        Ok(Fcf {
            typ: typ,
            usl: usl,
            modifiers: modifiers,
            drf: drf,
        })
    } else {
        Err("Missing or invalid type".to_owned())
    }
}

fn process_tiers(items: pest::iterators::Pairs<Rule>) -> Result<Vec<Fcf>, String>
{
    let mut result = Vec::<Fcf>::new();

    for item in items {
        match item.as_rule() {
            Rule::EOI => {},
            Rule::fcf_tier => result.push(process_fcf_tier(item.into_inner())?),
            _ => return Err(format!("Unexpected @ process_tiers: {:?}", item)), 
        }
    }

    Ok(result)
}
