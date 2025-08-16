module ChangeTracking
  extend ActiveSupport::Concern
  
  included do
    attr_accessor :current_user
    
    after_create :log_creation_version
    after_update :log_update_version
  end
  
  class_methods do
    # Define the fields to track for each model
    def track_changes(*fields)
      @tracked_fields = fields
    end
    
    def tracked_fields
      @tracked_fields || []
    end
    
    # Define the version model association name
    def version_association(association_name)
      @version_association = association_name
      has_many association_name, dependent: :destroy
    end
    
    def version_association_name
      @version_association || :versions
    end
  end
  
  # Instance methods for change tracking
  def log_view_by(user)
    return unless user
    
    create_version_record(
      user: user,
      action: 'viewed',
      change_details: "#{user.display_name} viewed #{model_display_name}"
    )
  end
  
  private
  
  def log_creation_version
    return unless current_user
    
    create_version_record(
      user: current_user,
      action: 'created',
      change_details: build_creation_summary,
      **creation_field_values
    )
  end
  
  def log_update_version
    return unless current_user
    
    if saved_changes.any?
      create_version_record(
        user: current_user,
        action: 'updated',
        change_details: build_change_summary,
        **change_field_values
      )
    end
  end
  
  def create_version_record(attributes)
    version_class = self.class.version_association_name.to_s.classify.constantize
    foreign_key = "#{self.class.name.underscore}_id"
    
    version_attributes = {
      foreign_key => id,
      **attributes
    }
    
    version_class.create!(version_attributes)
  end
  
  def model_display_name
    if respond_to?(:name)
      "#{self.class.name.underscore.humanize} '#{name}'"
    else
      "#{self.class.name.underscore.humanize} ##{id}"
    end
  end
  
  def build_creation_summary
    if respond_to?(:name)
      "Created new #{self.class.name.underscore.humanize.downcase} '#{name}'"
    else
      "Created new #{self.class.name.underscore.humanize.downcase}"
    end
  end
  
  def build_change_summary
    changes_list = []
    
    self.class.tracked_fields.each do |field|
      if saved_change_to_attribute?(field)
        old_value, new_value = saved_change_to_attribute(field)
        formatted_change = format_field_change(field, old_value, new_value)
        changes_list << formatted_change if formatted_change
      end
    end
    
    changes_list.join("; ")
  end
  
  def creation_field_values
    field_values = {}
    
    self.class.tracked_fields.each do |field|
      field_values["new_#{field}"] = send(field) if respond_to?(field)
    end
    
    field_values
  end
  
  def change_field_values
    field_values = {}
    
    self.class.tracked_fields.each do |field|
      if saved_change_to_attribute?(field)
        old_value, new_value = saved_change_to_attribute(field)
        field_values["previous_#{field}"] = old_value
        field_values["new_#{field}"] = new_value
      end
    end
    
    field_values
  end
  
  def format_field_change(field, old_value, new_value)
    case field.to_s
    when /.*_type$/
      # Handle enum types
      "#{field.to_s.humanize} changed from '#{format_enum_value(field, old_value)}' to '#{format_enum_value(field, new_value)}'"
    when /.*_amount$/, /.*_value$/, /amount$/, /allocated$/, /capital$/
      # Handle currency amounts
      old_formatted = format_currency_value(old_value)
      new_formatted = format_currency_value(new_value)
      "#{field.to_s.humanize} changed from #{old_formatted} to #{new_formatted}"
    when /rate$/
      # Handle rates/percentages
      "#{field.to_s.humanize} changed from #{old_value}% to #{new_value}%"
    else
      # Handle regular string/text fields
      "#{field.to_s.humanize} changed from '#{old_value}' to '#{new_value}'"
    end
  end
  
  def format_enum_value(field, value)
    return value unless value.is_a?(Integer)
    
    enum_mapping = self.class.send(field.to_s.pluralize) rescue {}
    enum_key = enum_mapping.key(value)
    enum_key ? enum_key.humanize : value.to_s
  end
  
  def format_currency_value(value)
    return "N/A" unless value.present?
    ActionController::Base.helpers.number_to_currency(value, precision: 0)
  end
end