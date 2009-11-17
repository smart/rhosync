require 'soap/wsdlDriver'

class SugarAdapter < SourceAdapter

  attr_accessor :module_name
  attr_accessor :order_by
  attr_accessor :select_fields 
  attr_accessor :query_filter
    
  attr_accessor :client
  
  def initialize(source,credential)
    puts "SugarCRM initialize with #{source.inspect.to_s}"
    
    super(source,credential)
    
    @select_fields = [] # leave empty like this to get all fields
    @order_by = ''
    @query_filter = '' # you can also use SQL like 'accounts.name like '%company%''
    
    url = (credential and !credential.url.blank?) ? credential.url : source.url
    p "Creating adapter for "+ url if url
    begin
      @client = SOAP::WSDLDriverFactory.new(url).create_rpc_driver
    rescue RuntimeError => e
      p "Failed to create WSDL driver: " + e.to_s
    end
    @client.options['protocol.http.receive_timeout'] = 3600 
  end

  def login
    puts "SugarCRM #{@module_name} login"
    if @source.credential and !@source.credential.login.blank?
      u = @source.credential.login
      p = Digest::MD5.hexdigest(@source.credential.password)
    else
      u = @source.login
      p "Login "+u
      p = Digest::MD5.hexdigest(@source.password)
    end
  
    ua = {'user_name' => u,'password' => p}
    ss = @client.login(ua,nil)
    if ss.error.number.to_i != 0
      p "failed to login - #{ss.error.description} with #{u},#{p}"
      raise "Failed to login"
      return
    else
      @session_id = ss['id']
      uid = @client.get_user_id(@session_id)
    end
  end

  def query(conditions=nil)
    puts "SugarCRM #{@module_name} query with conditions: #{conditions.inspect.to_s}" if conditions
    offset = 0
    max_results = '10000' # if set to 0 or '', this doesn't return all the results
    deleted = 0 # whether you want to retrieve deleted records, too
    @query_filter=hash_to_whereclause(conditions)
    @count = @client.get_entries_count(@session_id,@module_name,@query_filter,deleted).result_count
    puts "@count =#{@count} for #{@query_filter}" 
    @result = @client.get_entry_list(@session_id,@module_name,@query_filter,@order_by,offset,@select_fields,max_results,deleted)  
  end
  
  def hash_to_whereclause(conditions)
    whereclause=''
    first=true
    if conditions
      conditions.keys.each do |x|
        (whereclause=whereclause+' and ') if !first
        whereclause=whereclause+"(#{x}='#{conditions[x]}')"
        first=nil
      end
    end
    whereclause
  end
  
  # this gets a page at a time of information from the SugarCRM backend
  # def page(num)
  #   puts "SugarCRM #{@module_name} page"
  #   letter='A'
  #   num.times {letter=letter.next}
  #   if letter.size>1
  #     nil
  #   else
  #     p "Page #{letter}"
  #   
  #     offset = 0
  #     max_results = '10000' # if set to 0 or '', this doesn't return all the results
  #     deleted = 0 # whether you want to retrieve deleted records, too
  # 
  #     @query_filter="#{@module_name.downcase}.name like '#{letter}%'"
  #     p "Querying #{@query_filter}"
  #     @count = @client.get_entries_count(@session_id,@module_name,@query_filter,deleted).result_count
  #     puts "@count =#{@count}"
  #     @result = @client.get_entry_list(@session_id,@module_name,@query_filter,@order_by,offset,@select_fields,max_results,deleted)
  #   end
  # end
  
  def sugar_to_generic_results(sugar_result)
    p "Converting SugarCRM results to HASH OF HASHES generic results"
    generic_results={}
    sugar_result.entry_list.each do |entry|
      result={}
      entry.name_value_list.each do |nv|
        result[nv["name"]]=nv["value"]
      end
      generic_results[entry['id']] = result
    end
    generic_results
  end
  
  def sync
    puts "SugarCRM #{@module_name} sync with #{@result.entry_list.length}"
   @result=sugar_to_generic_results(@result)
    super 
  end


  def create(name_value_list)
    puts "SugarCRM #{@module_name} create #{name_value_list.inspect.to_s}"
    
    result=@client.set_entry(@session_id,@module_name,name_value_list)
  end

  def update(name_value_list)
    puts "SugarCRM #{@module_name} update #{name_value_list.inspect.to_s}"
    
    result=@client.set_entry(@session_id,@module_name,name_value_list)
  end

  def delete(name_value_list)
    puts "SugarCRM #{@module_name} delete #{name_value_list.inspect.to_s}"
    
    name_value_list.push({'name'=>'deleted','value'=>'1'});
    result=@client.set_entry(@session_id,@module_name,name_value_list)
  end

  def logoff
    @client.logout(@session_id)
  end
  
  def set_callback(notify_url)
  end
end