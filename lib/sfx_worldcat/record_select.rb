require 'marc'

module SFXWorldcat

  include SFXWorldcat::SFX
  include SFXWorldcat::Worldcat

  ### First look for a DLC record for the e-ISSN given (first electronic, then print), then do the same for a print ISSN;
  ### if not found in that way, move to LCCN (first electronic, then serial),
  ### then loop back around and look for a non-DLC e-ISSN record cataloged in English, then a non-DLC print record cataloged in English;
  ### finally, look at the OCLC number
  def process_issn_el_object(identifiers)
    apis = 0
    issn_el_value = nil
    issn_print_value = nil
    lccn_value = nil
    oclc_value = nil
    identifiers.each do |identifier|
      case [identifier['type'], identifier['sub_type']]
      when %w[ISSN ELECTRONIC]
        issn_el_value = identifier['value']
      when %w[ISSN PRINT]
        issn_print_value = identifier['value']
      when ['LCCN', '']
        lccn_value = identifier['value']
      when ['OCLC_NR', '']
        oclc_value = identifier['value']
      end
    end
    record_coll = worldcat_sru(issn_first_query(issn_el_value), 5)
    apis += 1
    record_coll = issn_rec_test(record_coll, issn_el_value) if record_coll
    unless record_coll
      record_coll = worldcat_sru(issn_second_query(issn_el_value), 5)
      apis += 1
      record_coll = issn_rec_test(record_coll, issn_el_value) if record_coll
    end
    return [record_coll, apis] if record_coll
    if issn_print_value
      record_coll = worldcat_sru(issn_first_query(issn_print_value))
      apis += 1
      record_coll = issn_rec_test(record_coll, issn_print_value) if record_coll
    end
    unless record_coll
      record_coll = worldcat_sru(issn_second_query(issn_print_value))
      apis += 1
      record_coll = issn_rec_test(record_coll, issn_print_value) if record_coll
    end
    return [record_coll, apis] if record_coll
    if lccn_value
      record_coll = worldcat_sru(lccn_first_query(lccn_value))
      apis += 1
      unless record_coll
        record_coll = worldcat_sru(lccn_second_query(lccn_value))
        apis += 1
      end
    end
    return [record_coll, apis] if record_coll
    record_coll = worldcat_sru(issn_third_query(issn_el_value), 10)
    apis += 1
    record_coll = issn_rec_test(record_coll, issn_el_value) if record_coll
    return [record_coll, apis] if record_coll
    if issn_print_value
      record_coll = worldcat_sru(issn_third_query(issn_print_value), 10)
      apis += 1
      record_coll = issn_rec_test(record_coll, issn_print_value) if record_coll
      unless record_coll
        record_coll = worldcat_sru(issn_final_query(issn_print_value), 10)
        apis += 1
        record_coll = issn_rec_test(record_coll, issn_print_value) if record_coll
      end
    end
    return [record_coll, apis] if record_coll
    record_coll = worldcat_sru(issn_final_query(issn_el_value), 10)
    apis += 1
    record_coll = issn_rec_test(record_coll, issn_el_value) if record_coll
    return [record_coll, apis] if record_coll
    if oclc_value
      record_coll = worldcat_sru(oclc_no_query(oclc_value))
      apis += 1
      if record_coll
        reader = MARC::XMLReader.new(StringIO.new(record_coll))
        record = reader.first
        record_coll = nil unless record['040']['b'].nil? || record['040']['b'] == 'eng'
      end
    end
    [record_coll, apis]
  end

  ### First look for a DLC record for the ISSN given (electronic, then print);
  ### if not found in that way, move to LCCN (electronic, then serial),
  ### then look for a non-DLC ISSN record cataloged in English;
  ### finally, look at the OCLC number
  def process_issn_print_object(identifiers)
    apis = 0
    issn_print_value = nil
    lccn_value = nil
    oclc_value = nil
    identifiers.each do |identifier|
      case [identifier['type'], identifier['sub_type']]
      when %w[ISSN PRINT]
        issn_print_value = identifier['value']
      when ['LCCN', '']
        lccn_value = identifier['value']
      when ['OCLC_NR', '']
        oclc_value = identifier['value']
      end
    end
    record_coll = worldcat_sru(issn_first_query(issn_print_value))
    apis += 1
    record_coll = issn_rec_test(record_coll, issn_print_value) if record_coll
    unless record_coll
      record_coll = worldcat_sru(issn_second_query(issn_print_value))
      apis += 1
      record_coll = issn_rec_test(record_coll, issn_print_value) if record_coll
    end
    return [record_coll, apis] if record_coll
    if lccn_value
      record_coll = worldcat_sru(lccn_first_query(lccn_value))
      apis += 1
      unless record_coll
        record_coll = worldcat_sru(lccn_second_query(lccn_value))
        apis += 1
      end
    end
    return [record_coll, apis] if record_coll
    record_coll = worldcat_sru(issn_third_query(issn_print_value), 10)
    apis += 1
    record_coll = issn_rec_test(record_coll, issn_print_value) if record_coll
    unless record_coll
      record_coll = worldcat_sru(issn_final_query(issn_print_value), 10)
      apis += 1
      record_coll = issn_rec_test(record_coll, issn_print_value) if record_coll
    end
    return [record_coll, apis] if record_coll
    if oclc_value
      record_coll = worldcat_sru(oclc_no_query(oclc_value))
      apis += 1
      if record_coll
        reader = MARC::XMLReader.new(StringIO.new(record_coll))
        record = reader.first
        record_coll = nil unless record['040']['b'].nil? || record['040']['b'] == 'eng'
      end
    end
    [record_coll, apis]
  end

  ### First look for an LCCN record (first electronic, then print);
  ### then, look at the OCLC number
  def process_lccn_object(identifiers)
    apis = 0
    lccn_value = nil
    oclc_value = nil
    identifiers.each do |identifier|
      case [identifier['type'], identifier['sub_type']]
      when ['LCCN', '']
        lccn_value = identifier['value']
      when ['OCLC_NR', '']
        oclc_value = identifier['value']
      end
    end
    record_coll = worldcat_sru(lccn_first_query(lccn_value))
    apis += 1
    unless record_coll
      record_coll = worldcat_sru(lccn_second_query(lccn_value))
      apis += 1
    end
    return [record_coll, apis] if record_coll
    if oclc_value
      record_coll = worldcat_sru(oclc_no_query(oclc_value))
      apis += 1
      if record_coll
        reader = MARC::XMLReader.new(StringIO.new(record_coll))
        record = reader.first
        record_coll = nil unless record['040']['b'].nil? || record['040']['b'] == 'eng'
      end
    end
    [record_coll, apis]
  end

  ### Only OCLC numbers remaining at this point
  def process_oclc_object(identifiers)
    apis = 0
    oclc_value = nil
    identifiers.each do |identifier|
      case [identifier['type'], identifier['sub_type']]
      when ['OCLC_NR', '']
        oclc_value = identifier['value']
      end
    end
    record_coll = worldcat_sru(oclc_no_query(oclc_value))
    apis += 1
    if record_coll
      reader = MARC::XMLReader.new(StringIO.new(record_coll))
      record = reader.first
      record_coll = nil unless record['040']['b'].nil? || record['040']['b'] == 'eng'
    end
    [record_coll, apis]
  end
end
