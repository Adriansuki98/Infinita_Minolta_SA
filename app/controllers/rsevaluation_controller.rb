class RsevaluationController < ApplicationController
  before_filter :authenticate_user!
  skip_after_filter :discard_flash

  def start
    evaluationStatus = current_subject.rsevaluation.nil? ? "0" : current_subject.rsevaluation.status
    return redirect_to(user_path(current_subject), :notice => I18n.t("rsevaluation.messages.duplicated")) if evaluationStatus == "Finished"

    case evaluationStatus
    when "0"
      #No data needed for step1
      render :step1
    when "1"
      #Data for step2
      rsevaluation = current_subject.rsevaluation
      rsData = JSON.parse(rsevaluation.data)
      
      if rsData["step2_pre"].nil?
        #Generate data for step2
        step2data = {}

        lo = getLoStep2(rsData["step1"]["topic"],current_subject.language)
        resources_CQ = RecommenderSystemAB.resource_suggestions({:lo => lo, :n=>5, :models => [Excursion], :request => request},"cq",true)[0]
        resources_C = RecommenderSystemAB.resource_suggestions({:lo => lo, :n=>5, :models => [Excursion], :request => request},"c",true)[0]
        resources_Q = RecommenderSystemAB.resource_suggestions({:lo => lo, :n=>5, :models => [Excursion], :request => request},"q",true)[0]
        resources_R = RecommenderSystemAB.resource_suggestions({:lo => lo, :n=>5, :models => [Excursion], :request => request},"r",true)[0]
        items = (resources_CQ + resources_C + resources_Q + resources_R).uniq.shuffle

        step2data["lo_id"] = lo.id
        step2data["resources_cq"] = resources_CQ.map{|r| r.id}
        step2data["resources_c"] = resources_C.map{|r| r.id}
        step2data["resources_q"] = resources_Q.map{|r| r.id}
        step2data["resources_r"] = resources_R.map{|r| r.id}
        step2data["items"] = items.map{|r| r.id}

        step2data["user_profile"] = {}
        step2data["user_profile"]["language"] = current_subject.language

        rsData["step2_pre"] = step2data
        rsevaluation.data = rsData.to_json
        rsevaluation.save!
        data = JSON.parse(rsevaluation.data)["step2_pre"]
      else
        data = rsData["step2_pre"]
      end

      @lo = Excursion.find_by_id(data["lo_id"])
      @items = Excursion.find(data["items"])

      #Restore draft
      unless rsData["step2_draft"].blank? or rsData["step2_draft"]["relevances"].blank?
        @relevances = rsData["step2_draft"]["relevances"]
      end

      render :step2
    when "2"
      #Data for step3
      #TODO
      render :step3
    else
      return redirect_to(user_path(current_subject), :alert => "Evaluation at wrong state. Please contact the ViSH team.")
    end
  end

  #Redirect to the corresponding step
  def step
    case params[:step]
    when "1"
      step1
    when "2"
      step2
    when "3"
      step3
    else
      redirect_to "/rsevaluation"
    end
  end

  #Redirect to the corresponding step_draft
  def step_draft
    case params[:step]
    when "2"
      step2_draft
    else
      redirect_to "/rsevaluation"
    end
  end

  #Save step1
  def step1
    userData = JSON.parse(params["data"]) rescue {}
    #Data validation.
    errors = []
    errors << I18n.t("rsevaluation.messages.missing_topic") if userData["topic"].blank?
    return redirect_to("/rsevaluation", :alert => errors.first) unless errors.blank?

    e = Rsevaluation.new
    e.actor_id = Actor.normalize_id(current_subject)
    e.status = "1"
    data = {}
    data["step1"] = {};
    data["step1"]["topic"] = userData["topic"]
    e.data = data.to_json
    e.save!
    redirect_to "/rsevaluation"
  end

  #Save step2
  def step2
    userData = JSON.parse(params["data"]) rescue {}
    #Data validation.
    errors = []
    if userData["relevances"].blank?
      errors << "Missing data"
    else
      errors << "Incorrect relevances" unless userData["relevances"].keys.map{|k| userData["relevances"][k]}.select{|r| r.nil?}.blank?
    end
    return redirect_to("/rsevaluation", :alert => errors.first) unless errors.blank?

    e = current_subject.rsevaluation

    data = JSON.parse(e.data)
    data["step2"] = {}
    data["step2"]["relevances"] = userData["relevances"]
    
    e.data = data.to_json
    e.status = "2"
    e.save!
    redirect_to "/rsevaluation"
  end

  #Draft step2
  def step2_draft
    userData = JSON.parse(params["data"]) rescue {}
    return redirect_to("/rsevaluation", :notice => I18n.t("rsevaluation.messages.draft_success")) if userData["relevances"].blank?

    e = current_subject.rsevaluation
    data = JSON.parse(e.data)
    data["step2_draft"] = {}
    data["step2_draft"]["relevances"] = userData["relevances"]
    e.data = data.to_json
    e.save!

    redirect_to("/rsevaluation", :notice => I18n.t("rsevaluation.messages.draft_success"))
  end

  #Save step3
  def step3
    userData = JSON.parse(params["data"]) rescue {}
    #Data validation.
    errors = []
    return redirect_to("/rsevaluation", :alert => errors.first) unless errors.blank?

    e = current_subject.rsevaluation

    data = JSON.parse(e.data)
    data["step3"] = {}
    data["step3"]["user_data"] = userData

    e.data = data.to_json
    e.status = "Finished"
    e.save!

    redirect_to(user_path(current_subject), :notice => I18n.t("rsevaluation.messages.success"))
  end


  private

  def getLoStep2(topic,ulanguage)
    case topic
    when "A"
    when "B"
    when "C"
    else
    end
    return Excursion.last
  end

end