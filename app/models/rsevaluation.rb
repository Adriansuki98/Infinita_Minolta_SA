class Rsevaluation < ActiveRecord::Base
  validates :actor_id, :presence => true, :uniqueness => true
  validates :data, :presence => true
  validates_inclusion_of :status, :in => ["0","1","2","Finished"], :allow_nil => false

  belongs_to :actor

  #Utils for ViSHRS evaluation
  def self.getActivityObjectJSON(ao)
    if ao.is_a? Array
      return ao.map{|el| getActivityObjectJSON(el)}
    else
      ao = ao.respond_to?("activity_object") ? ao.activity_object : ao
      json = {
        :id => ao.id.to_s,
        :type => ao.getType,
        :created_at => ao.created_at.strftime("%d-%m-%Y"),
        :updated_at => ao.updated_at.strftime("%d-%m-%Y"),
        :title => ao.title,
        :description => ao.description,
        :language => ao.language,
        :tags => ao.tag_list
      }
      json[:name] = ao.name if ao.respond_to?("name")
      return json
    end
  end
end