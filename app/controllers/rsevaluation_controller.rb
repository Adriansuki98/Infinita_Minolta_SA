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
      #No data needed for step2
      render :step2
    when "2"
      #Data for step3
      rsevaluation = current_subject.rsevaluation
      rsData = JSON.parse(rsevaluation.data)
      
      if rsData["step3_pre"].nil?
        #Generate data for step3
        step3data = {}

        lo = getLoStep3(rsData["step2"]["topic"],current_subject.language)
        resources_CQ = RecommenderSystemAB.resource_suggestions({:lo => lo, :n=>5, :models => [Excursion], :request => request},"cq",true)[0]
        resources_C = RecommenderSystemAB.resource_suggestions({:lo => lo, :n=>5, :models => [Excursion], :request => request},"c",true)[0]
        resources_Q = RecommenderSystemAB.resource_suggestions({:lo => lo, :n=>5, :models => [Excursion], :request => request},"q",true)[0]
        resources_R = RecommenderSystemAB.resource_suggestions({:lo => lo, :n=>5, :models => [Excursion], :request => request},"r",true)[0]
        items = (resources_CQ + resources_C + resources_Q + resources_R).uniq.shuffle

        step3data["lo_id"] = lo.id
        step3data["resources_cq"] = resources_CQ.map{|r| r.id}
        step3data["resources_c"] = resources_C.map{|r| r.id}
        step3data["resources_q"] = resources_Q.map{|r| r.id}
        step3data["resources_r"] = resources_R.map{|r| r.id}
        step3data["items"] = items.map{|r| r.id}

        step3data["user_profile"] = {}
        step3data["user_profile"]["language"] = current_subject.language

        rsData["step3_pre"] = step3data
        rsevaluation.data = rsData.to_json
        rsevaluation.save!
        data = JSON.parse(rsevaluation.data)["step3_pre"]
      else
        data = rsData["step3_pre"]
      end

      @lo = Excursion.find_by_id(data["lo_id"])
      @items = Excursion.find(data["items"])

      #Restore draft
      unless rsData["step3_draft"].blank? or rsData["step3_draft"]["relevances"].blank?
        @relevances = rsData["step3_draft"]["relevances"]
      end

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
    when "3"
      step3_draft
    else
      redirect_to "/rsevaluation"
    end
  end

  #Save step1
  def step1
    userData = JSON.parse(params["data"]) rescue {}
    #Data validation.
    errors = []
    errors << I18n.t("rsevaluation.messages.missing_data_in_form") if (userData["age"].blank? or userData["gender"].blank? or userData["occupation"].blank? or userData["lor_exp"].blank?)
    return redirect_to("/rsevaluation", :alert => errors.first) unless errors.blank?

    e = Rsevaluation.new
    e.actor_id = Actor.normalize_id(current_subject)
    e.status = "1"
    data = {}
    data["step1"] = {};
    data["step1"]["age"] = userData["age"]
    data["step1"]["gender"] = userData["gender"]
    e.data = data.to_json
    e.save!
    redirect_to "/rsevaluation"
  end

  def step2
    userData = JSON.parse(params["data"]) rescue {}
    #Data validation.
    errors = []
    errors << I18n.t("rsevaluation.messages.missing_topic") if userData["topic"].blank?
    return redirect_to("/rsevaluation", :alert => errors.first) unless errors.blank?

    e = current_subject.rsevaluation
    e.status = "2"
    data = {}
    data["step2"] = {};
    data["step2"]["topic"] = userData["topic"]
    e.data = data.to_json
    e.save!
    redirect_to "/rsevaluation"
  end

  def step3
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
    data["step3"] = {}
    data["step3"]["relevances"] = userData["relevances"]
    
    e.data = data.to_json
    e.status = "Finished"
    e.save!
    redirect_to(user_path(current_subject), :notice => I18n.t("rsevaluation.messages.success"))
  end

  def step3_draft
    userData = JSON.parse(params["data"]) rescue {}
    return redirect_to("/rsevaluation", :notice => I18n.t("rsevaluation.messages.draft_success")) if userData["relevances"].blank?

    e = current_subject.rsevaluation
    data = JSON.parse(e.data)
    data["step3_draft"] = {}
    data["step3_draft"]["relevances"] = userData["relevances"]
    e.data = data.to_json
    e.save!

    redirect_to("/rsevaluation", :notice => I18n.t("rsevaluation.messages.draft_success"))
  end

  private

  def getLoStep3(topic,ulanguage)
    case topic
    when "engineering"
      if ulanguage === "es"
        return [Excursion.find(2211),Excursion.find(605),Excursion.find(2352),Excursion.find(2277),Excursion.find(1143)].sample(1).first
      else
        return [Excursion.find(474),Excursion.find(64),Excursion.find(522),Excursion.find(1565),Excursion.find(421),Excursion.find(435)].sample(1).first
      end
    when "biology"
      if ulanguage === "es"
        return [Excursion.find(498), Excursion.find(470), Excursion.find(509), Excursion.find(497),Excursion.find(514),Excursion.find(499)].sample(1).first
      else
        return [Excursion.find(76), Excursion.find(400)].sample(1).first
      end
    when "physics"
      if ulanguage === "es"
        return [Excursion.find(655), Excursion.find(1860)].sample(1).first
      else
        return [Excursion.find(522), Excursion.find(64)].sample(1).first
      end
    when "history"
      if ulanguage === "es"
        return [Excursion.find(2481), Excursion.find(1232), Excursion.find(2387), Excursion.find(2531)].sample(1).first
      else
        #History only available for ES language
        return nil
      end
    else
    end
  end

end