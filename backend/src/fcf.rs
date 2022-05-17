use std::fmt;
use serde::{Deserialize, Serialize};

#[derive(Debug, Copy, Clone, Serialize, Deserialize)]
pub enum GdtToleranceType {
    Position,
    Profile,
}

#[derive(Debug, Copy, Clone, Serialize, Deserialize)]
pub enum Modifier {
    NoModifier,
    MMC,
    LMC,
    SL,
}

#[derive(Clone, Serialize, Deserialize)]
pub struct Datum {
    pub label: String,
    //Reference: String,
}

impl fmt::Debug for Datum {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.label)
    }
}

#[derive(Clone, Serialize, Deserialize)]
pub enum DatumReference {
    Single(Datum),
    Compound(Vec<DatumUsage>),
}

impl fmt::Debug for DatumReference {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            DatumReference::Single(d) => d.fmt(f),
            DatumReference::Compound(l) => {
                write!(f, "(")?;
                for i in 0 .. l.len() {
                    l[i].fmt(f)?;
                    if i + 1 < l.len() {
                        write!(f," - ")?;
                    } else {
                        write!(f,")")?;
                    };
                };
                Ok(())
            }
        }
    }
}

#[derive(Clone, Serialize, Deserialize)]
pub struct DatumUsage {
    pub datum: DatumReference,
    pub modifiers: Vec<Modifier>,
}

impl fmt::Debug for DatumUsage 
{
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        self.datum.fmt(f)?;
        let mut first = true;
        for m in &self.modifiers {
            if first  {
                write!(f,": ")?;
                first = false;
            } else {
                write!(f,", ")?;
            }
            m.fmt(f)?;
        }
        Ok(())
    }
}

pub type Drf = Vec<DatumUsage>;

#[derive(Clone, Serialize, Deserialize)]
pub struct Fcf {
    pub typ: GdtToleranceType,
    //pub tier_index: u32,
    pub usl: String,
    pub modifiers: Vec<Modifier>,
    pub drf: Drf,
}

impl fmt::Debug for Fcf 
{
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f,"[ ")?;
        self.typ.fmt(f)?;
        write!(f," | {}", self.usl)?;        
        let mut first = true;
        for m in &self.modifiers {
            if first  {
                write!(f,": ")?;
                first = false;
            } else {
                write!(f,", ")?;
            }
            m.fmt(f)?;
        }
        for du in &self.drf {
            write!(f," | ")?;
            du.fmt(f)?;
        }
        write!(f," ]")?;
        Ok(())
    }
}

#[derive(Clone, Serialize, Deserialize)]
pub struct FullFcf { 
    pub tiers: Vec<Fcf>,
    pub human_readable : String
}

// impl fmt::Debug for Vec<Fcf>
// {
//     fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
//         Ok(())
//     }
// }