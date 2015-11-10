
namespace :deprecated do |ns|
  task :list do
    puts 'all tasks:'
    puts ns.tasks
  end

  task pfmerge_affluents: :environment do
    orig = SQLite3::Database.open "db/to_merge_affluents.sqlite3"

    stm = orig.prepare "select  dhcp.hash, http.hash, mac.vendor, dhcp.finger,dhcp.vendor_id, http.user_agent, http.suites, http.uaprof, dhcp.detect, mac.mac from dhcp 
                        inner join http on dhcp.mac=http.mac 
                        inner join mac on dhcp.mac = mac.mac"

    result = stm.execute

    result.each do |row|
      ic = Iconv.new('UTF-8//IGNORE', 'UTF-8')

      dhcp_fingerprint_value = ic.iconv(row[3] + ' ')[0..-2]
      user_agent_value = ic.iconv(row[5] + ' ')[0..-2]
      dhcp_vendor_value = ic.iconv(row[4] + ' ')[0..-2]
      mac_value = ic.iconv(row[9] + ' ')[0..-2][0..7]
      DhcpFingerprint.create(:value => dhcp_fingerprint_value)
      dhcp_fingerprint = DhcpFingerprint.where(:value => dhcp_fingerprint_value).first
      UserAgent.create(:value => user_agent_value)
      user_agent = UserAgent.where(:value => user_agent_value).first
      DhcpVendor.create(:value => dhcp_vendor_value)
      dhcp_vendor = DhcpVendor.where(:value => dhcp_vendor_value).first 

      combination = Combination.new
      combination.dhcp_fingerprint = dhcp_fingerprint
      combination.user_agent = user_agent
      combination.dhcp_vendor = dhcp_vendor
      combination.mac_vendor = MacVendor.from_mac(mac_value)
      combination.save
      combination = Combination.where(:user_agent => user_agent, :dhcp_fingerprint => dhcp_fingerprint, :dhcp_vendor => dhcp_vendor).first
    end

    puts "Done"    

  end

  task pfmerge_mts: :environment do
    orig = SQLite3::Database.open "db/to_merge_mts.sqlite3"

    stm = orig.prepare "select DISTINCT dhcp.hash, dhcp.finger,dhcp.vendor_id, dhcp.detect from dhcp;"

    result = stm.execute
    puts "hellO"
    result.each do |row|
      ic = Iconv.new('UTF-8//IGNORE', 'UTF-8')
      puts row
      
      dhcp_fingerprint_value = ic.iconv(row[1] + ' ')[0..-2]
      dhcp_vendor_value = ic.iconv(row[2] + ' ')[0..-2]
      user_agent_value = ""
      UserAgent.create(:value => user_agent_value)
      user_agent = UserAgent.where(:value => user_agent_value).first
      DhcpFingerprint.create(:value => dhcp_fingerprint_value)
      dhcp_fingerprint = DhcpFingerprint.where(:value => dhcp_fingerprint_value).first
      DhcpVendor.create(:value => dhcp_vendor_value)
      dhcp_vendor = DhcpVendor.where(:value => dhcp_vendor_value).first 

      combination = Combination.new
      combination.dhcp_fingerprint = dhcp_fingerprint
      combination.dhcp_vendor = dhcp_vendor
      combination.user_agent = user_agent
      combination.save
      combination = Combination.where(:dhcp_fingerprint => dhcp_fingerprint, :dhcp_vendor => dhcp_vendor).first
    end

    puts "Done"    

  end

  task import_pf_os: :environment do
    line_num=0
    text=File.open('tmp/os.csv').read
    text.gsub!(/\r\n?/, "\n")
    text.each_line do |line|
      print "#{line_num += 1} #{line}"
      line.gsub!(/\n/, "")
      Device.create!(:name => line)
    end
  end

  task import_pf_mappings: :environment do
    line_num=0
    text=File.open('tmp/mappings.csv').read
    text.gsub!(/\r\n?/, "\n")
    text.each_line do |line|
      puts "#{line_num += 1} #{line}"
      line.gsub!(/\n/, "")
      values = line.split(/!/)
      print values
      parent = Device.where(:name => values[1]).first
      child = Device.where(:name => values[0]).first
      unless parent.nil? or child.nil?
        child.parent = parent
        child.save!
      else
        puts "Can't process #{line}"
      end
    end
  end

  task import_pf_dhcp_fingerprints: :environment do
    line_num=0
    text=File.open('tmp/dhcp_fingerprints.csv').read
    text.gsub!(/\r\n?/, "\n")
    text.each_line do |line|
      puts "#{line_num += 1} #{line}"
      line.gsub!(/\n/, "")
      values = line.split(/\|/)
      print values
      device = Device.where(:name => values[1]).first
      unless device.nil?
        dhcp_fingerprint = DhcpFingerprint.new(:value => values[0])
        dhcp_fingerprint.save
        
        discoverer_name = "Imported from PF (#{values[1]})"
        discoverer = Discoverer.where(:device => device, :description => discoverer_name).first
        if discoverer.nil?
          discoverer = Discoverer.create(:description => discoverer_name, :priority => 50)
          device.discoverers.push discoverer
        end
        discoverer.device_rules.push Rule.new(:value=> "dhcp_fingerprints.value='#{values[0]}'")
        discoverer.save
        device.save
      else
        puts "Can't process #{line}"
      end
    end
  end

  task reorganize_tree: :environment do
    # Androids
    generic_android = Device.where(:name => "Generic Android").first
    Device.where("name LIKE '%Android%' AND NOT name='Generic Android'").each do |device| 
      device.parent = generic_android
      device.save!
    end
    Device.where(:name => "Samsung Galaxy Tab 3 7.0 SM-T210R").first.update!(:parent => generic_android)
    Device.where(:name => "Samsung S8000").first.update!(:parent => generic_android)
    Device.where(:name => "Samsung S8500").first.update!(:parent => generic_android)
    Device.where(:name => "LG G2 F320").first.update!(:parent => generic_android)
    Device.where(:name => "Kindle HD").first.update!(:parent => generic_android)
    Device.where(:name => "Samsung GT-S5690M (Galaxy Ruby)").first.update!(:parent => generic_android)

    # CD based OS are all linux
    cd_cat = Device.where(:name => "CD-Based OSes").first
    cd_device = Device.where(:parent => cd_cat)
    cd_device.each do |device|
      device.update!(:parent => Device.where(:name => "Linux").first)
    end
    cd_cat.destroy!

    # Apple iPod should be under Apple iPod, iPhone or iPad
    Device.where(:name => "Apple iPod").first.update!(:parent => Device.where(:name => "Apple iPod, iPhone or iPad").first)
    # Create Apple iPhone and Apple iPad
    Device.create!(:name => "Apple iPhone", :parent => Device.where(:name => "Apple iPod, iPhone or iPad").first)
    Device.create!(:name => "Apple iPad", :parent => Device.where(:name => "Apple iPod, iPhone or iPad").first)
  end

  task sample_rules: :environment do
    match = "user_agents.value regexp '.*Android ([0-9]+).*'"
    version_extractor = "PREG_CAPTURE('/.*Linux; U; Android ([0-9.]+).*/', user_agents.value, 1)"
    discoverer = Discoverer.new(:description => "Android version from user agent", :priority => 5, :device => Device.where(:name => "Generic Android").first, :version => version_extractor)
    discoverer.version_rules << Rule.create!(:value => match)
    discoverer.save!

    match = "user_agents.value regexp '.*Android ([0-9]+).*' AND dhcp_vendors.value like 'dhcpcd%'"
    discoverer = Discoverer.new(:description => "Android from user agent and dhcp vendor id", :priority => 40, :device => Device.where(:name => "Generic Android").first)
    discoverer.device_rules << Rule.create!(:value => match)
    discoverer.save!

    match = "user_agents.value regexp '.*\\\\(iPad;.*'"
    discoverer = Discoverer.new(:description => "iPad from user agent", :priority => 5, :device => Device.where(:name => "Apple iPad").first)
    discoverer.device_rules << Rule.create!(:value => match)
    discoverer.save!

    match = "user_agents.value regexp '.*\\\\(iPhone;.*'"
    discoverer = Discoverer.new(:description => "iPhone from user agent", :priority => 5, :device => Device.where(:name => "Apple iPhone").first)
    discoverer.device_rules << Rule.create!(:value => match)
    discoverer.save!

    match = "user_agents.value regexp '.*\\\\(iPod;.*'"
    discoverer = Discoverer.new(:description => "iPod from user agent", :priority => 5, :device => Device.where(:name => "Apple iPod").first)
    discoverer.device_rules << Rule.create!(:value => match)
    discoverer.save!

    match = "user_agents.value regexp '.*[0-9_]+ like Mac OS X.*' and dhcp_vendors.value = '' and dhcp_fingerprints.value != ''"
    version_extractor = "REPLACE(PREG_CAPTURE('/.* ([0-9_]+) like Mac OS X.*/',user_agents.value,1), '_', '.')"
    discoverer = Discoverer.new(:description => "IOS version from user agent", :priority => 5, :device => Device.where(:name => "Apple iPod, iPhone or iPad").first, :version => version_extractor) 
    discoverer.version_rules << Rule.create!(:value => match)
    discoverer.save!

    match = "dhcp_vendors.value like 'BlackBerry%' and dhcp_fingerprints.value='1,3,6'"
    discoverer = Discoverer.new(:description => "Detect blackberries from DHCP vendor id", :priority => 60, :device => Device.where(:name => "RIM BlackBerry").first)
    discoverer.device_rules << Rule.create!(:value => match)
    discoverer.save!

    match = "dhcp_vendors.value like 'BlackBerry OS%'"
    version_extractor = "PREG_CAPTURE('/.*BlackBerry OS ([0-9.]+).*/', dhcp_vendors.value, 1)"
    discoverer = Discoverer.new(:description => "BlackBerry version from DHCP vendor", :priority => 5, :device => Device.where(:name => "RIM BlackBerry").first, :version => version_extractor)
    discoverer.version_rules << Rule.create!(:value => match)
    discoverer.save!

  end
end
