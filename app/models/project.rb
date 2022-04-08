class Project < ApplicationRecord

  attr_accessor :longitude, :latitude

  belongs_to :author, class_name: 'User'

  has_many :affiliations, dependent: :delete_all
  has_many :organizations, through: :affiliations

  accepts_nested_attributes_for :affiliations

  before_save :assign_lonlat, :assign_state

  has_many_attached :photos

  validates :name, :stream_name, :implementation_date, :primary_contact,
            :longitude, :latitude, :narrative, :structure_description, :watershed,
            :url, presence: true

  validates_numericality_of :length, only_integer: true, greater_than: 0
  validates_numericality_of :latitude, greater_than: -90, less_than: 90, message: 'must be in decimal notation'
  validates_numericality_of :longitude, greater_than: -180, less_than: 180, message: 'must be in decimal notation'
  validates_numericality_of :number_of_structures, only_integer: true, greater_than: 0

  validates_format_of :implementation_date, :with => /\d{4}\-\d{2}\-\d{2}/, :message => 'must be in the following format: yyyy-mm-dd'

  validates :photos, 
    content_type: [:png, :jpg, :jpeg, :gif, :bmp, :avif, :webp], 
    size: { less_than: 50.megabytes , message: 'must be below 50 MB in size each' }, 
    limit: { min: 0, max: 20, message: 'must have fewer than 20 photos'}

  def title
    "Project on #{stream_name}"
  end


  def byline
    if affiliation.present?
      "Implemented on #{implementation_date.to_formatted_s(:long)} in affiliation with #{affiliation}"
    else
      "Implemented on #{implementation_date.to_formatted_s(:long)}"
    end
  end

  def calculate_state
    point = "SRID=4326;#{self.lonlat}"
    states = State.arel_table
    containing_state = State.where(states[:geom].st_contains(Arel.spatial(point)))
    return containing_state.present? ? containing_state.first.id : nil
  end

  def self.project_count
    all.count
  end

  def self.structure_sum
    sum(:number_of_structures)
  end

  def self.project_total_length_km
    total_km = sum(:length)/1000.to_f
    return total_km.round(1)
  end

  def self.search(search, search_organization)
    projects = Project.all
    
    if search && search_organization
        projects = projects.where(["projects.name LIKE :search", search: "%#{search}%"]).or(
        projects = projects.where(["projects.watershed LIKE :search", search: "%#{search}%"])).or(
        projects = projects.where(["stream_name LIKE :search", search: "%#{search}%"]))

        if search_organization.length > 0
            projects = projects.where(["projects.name LIKE :search", search: "%#{search}%"]).or(
            projects = projects.where(["projects.watershed LIKE :search", search: "%#{search}%"])).or(
            projects = projects.where(["stream_name LIKE :search", search: "%#{search}%"]))
                        .joins(:organizations).where(organizations: {id: search_organization})
        end
        return projects
    else
        all
    end
  end

  private

  def round_string(str, precision)
    return str.to_f.round(precision).to_s
  end

  def assign_lonlat
    if @longitude.present? && @latitude.present?
      mfactory = RGeo::ActiveRecord::SpatialFactoryStore.instance.factory(:geo_type => 'point')
      self.lonlat = mfactory.point(round_string(longitude, 6), round_string(latitude, 6))
    else
      throw(:abort)
    end
  end

  def assign_state
    self.state_id = calculate_state
  end

end
