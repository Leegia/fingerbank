

namespace :clean do |ns|
  task :list do
    puts 'all tasks:'
    puts ns.tasks
  end

  task delete_lost_causes: :environment do
    searches = [
      Regexp.new('^ALU_[0-9]+\\.[0-9]+\\.[0-9]+_'),
      Regexp.new('^%%%.*%%%$'),
      Regexp.new('^\\{\\w{8}-\\w{4}-\\w{4}-\\w{4}-\\w{12}\\}$'),
    ] 
    Combination.unknown.each do |c|
      searches.each do |search|
        match = c.user_agent.value.scan(search)
        if match[0]
          puts "#{c.id} : #{c.user_agent.value}"
          c.delete
        end
      end
    end
  end

  task delete_orphans: :environment do
    Proc.new{
      ua_ids = Combination.all.collect {|c| c.user_agent_id }
      ua_ids = ua_ids.uniq.sort
      UserAgent.where('id not in (?)', ua_ids).order(:id).each do |ua|
        puts "User agent : #{ua.id} '#{ua.value}' #{ua.created_at} is an orphan"
        ua.delete
      end
    }.call
  
    Proc.new{
      df_ids = Combination.all.collect {|c| c.dhcp_fingerprint_id }
      df_ids = df_ids.uniq
      DhcpFingerprint.where('id not in (?)', df_ids).order(:id).each do |df|
        puts "DHCP fingerprint : #{df.id} '#{df.value}' #{df.created_at} is an orphan"
        df.delete
      end
    }.call

    Proc.new{
      dv_ids = Combination.all.collect {|c| c.dhcp_vendor_id }
      dv_ids = dv_ids.uniq
      DhcpVendor.where('id not in (?)', dv_ids).order(:id).each do |dv|
        puts "DHCP vendor : #{dv.id} '#{dv.value}' #{dv.created_at} is an orphan"
        dv.delete
      end
    }.call

  end

end
