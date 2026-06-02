#import "template/locale.typ": TRADEMARK_NOTICE_HEADING, TRADEMARK_NOTICE_SINGLE, TRADEMARK_NOTICE_PLURAL, AND
#let trademark_notice(brands, owner, language) = {
  let with_r = brands.map(b => [#b®])
  let list = with_r.join(", ", last: [ #AND.at(language)])
  if brands.len() == 0 { [#list #TRADEMARK_NOTICE_SINGLE.at(language) #owner.] } else {
    [#list #TRADEMARK_NOTICE_PLURAL.at(language) #owner.]
  }
}

#let render_trademark_notices(dict, language) = {
  let owners = dict.keys()
  let lines = owners.map(o => trademark_notice(dict.at(o), o, language))
  lines.join([#linebreak()])
}


// --- Your dictionary of owner -> brands ---

#let trademarks = (
  "Beckhoff Automation GmbH": (
    "Beckhoff",
    "ATRO",
    "EtherCAT",
    "EtherCAT G",
    "EtherCAT G10",
    "EtherCAT P",
    "MX‑System",
    "Safety over EtherCAT",
    "TC/BSD",
    "TwinCAT",
    "TwinCAT/BSD",
    "TwinSAFE",
    "XFC",
    "XPlanar",
    "XTS",
  ),
  "XYZ Corporation": (
    "XYZ Product 1",
    "XYZ Product 2",
  ),
)

#let render_all_trademark_notices(sep: "parbreak", language) = {
  render_trademark_notices(trademarks, language)
}





