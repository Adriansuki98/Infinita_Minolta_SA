# encoding: utf-8

###############
# ViSH Recommender System
###############

class RecommenderSystemAB

  def self.resource_suggestions(options={},forceRS=nil,noTrack=false)
    # Step 0: Initialize all variables
    options = prepareOptions(options)

    #Step 1: Preselection
    preSelectionLOs = getPreselection(options)
    return preSelectionLOs if preSelectionLOs.blank?

    #Step 2: Scoring
    if forceRS.nil?
      rn = rand
    else
      #Force a specific recommender system (used in the user study)
      case forceRS
      when "cq"
        rn = 0.8
      when "c"
        rn = 0.6
      when "q"
        rn = 0.3
      when "r"
        rn = 0.2
      else
        raise "Unrecognized recommender system"
      end 
    end

    # rn = 0.3, for testing purposes
    if rn > 0.75
      #Case A. CB + Quality Metrics
      rankedLOs = RecommenderSystemCQ.calculateScore(preSelectionLOs,options)
      options[:recEngine] = "cq"
    elsif rn > 0.5
      #Case B. CB
      rankedLOs = RecommenderSystemC.calculateScore(preSelectionLOs,options)
      options[:recEngine] = "c"
    elsif rn > 0.25
      #Case C. Quality Metrics
      rankedLOs = RecommenderSystemQ.calculateScore(preSelectionLOs,options)
      options[:recEngine] = "q"
    else
      #Case D. Random
      rankedLOs = RecommenderSystemR.calculateScore(preSelectionLOs,options)
      options[:recEngine] = "r"
    end

    #Step 3: Sorting
    sortedLOs = rankedLOs.sort { |a,b|  b.score <=> a.score }

    #Step 4: Delivering
    deliveredLOs = sortedLOs.first(options[:n])

    options[:los] = deliveredLOs

    if noTrack
      tsentryId = nil
    else 
      tsentry = trackGeneratedRecommendation(options,options[:request],options[:user])
      tsentryId = (!tsentry.nil? and tsentry.persisted?) ? tsentry.id : nil
    end
    
    return [deliveredLOs,tsentryId]
  end


  # Step 0: Initialize all variables
  def self.prepareOptions(options)
    options = {:n => 10}.recursive_merge(options)
    options[:lo].tag_array_cached = options[:lo].tag_array if options[:lo]
    options
  end

  #Step 1: Preselection
  def self.getPreselection(options)
    preSelection = []
    ao_ids_to_avoid = (options[:lo] ? [options[:lo].activity_object.id] : [-1])

    # Get random resources using the Search Engine
    searchOpts = {}
    searchOpts[:order] = "random"

    # Preselection filters

    # A. Resource type.
    options[:models] = [options[:lo].class] if options[:lo]
    searchOpts[:models] = options[:models] #Only search for desired models
    
    # B. Quality
    searchOpts[:reviewers_qscore_loriam_int] = true

    # C. Repeated resources.
    # searchOpts[:subjects_to_avoid] = [options[:user]] if options[:user]
    searchOpts[:ao_ids_to_avoid] = ao_ids_to_avoid unless ao_ids_to_avoid.blank?

    # D. N
    searchOpts[:n] = [400,Vish::Application::config.rs_max_preselection_size].min

    #E. Date.
    searchOpts[:endDate] = Time.parse("1-3-2019")

    #Call search engine
    preSelection += (Search.search(searchOpts).compact rescue [])

    return preSelection
  end

  def self.trackGeneratedRecommendation(options,request,current_subject)
    return unless Vish::Application.config.trackingSystem
    return if TrackingSystemEntry.isBot?(request) or !TrackingSystemEntry.isDesktop?(request)
    return if options.blank? or !options[:recEngine].is_a? String or options[:lo].nil? or options[:los].blank?

    tsentry = TrackingSystemEntry.new
    tsentry.app_id = "ViSHRecommendations"
    tsentry.user_agent = request.user_agent
    tsentry.referrer = request.referrer
    tsentry.user_logged = (current_subject.nil? ? false : true)

    data = {}
    data["rsEngine"] = options[:recEngine]
    data["lo_id"] = options[:lo].id
    data["reclo_ids"] = options[:los].map{|lo| lo.id}

    tsentry.data = data.to_json
    tsentry.save

    return tsentry
  end

end