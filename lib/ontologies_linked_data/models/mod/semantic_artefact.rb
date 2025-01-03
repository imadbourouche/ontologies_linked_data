module LinkedData
    module Models

        class SemanticArtefact

            # SemanticArtefact attrs that map with ontology
            attr_accessor :id, :acronym, :type, :title, :accessRights, :group,  :theme, :hasEvaluation, :usedInProject, :creator

            # SemanticArtefact attrs that maps with submission
            attr_accessor :URI, :description, :language, :license, 
                          :rights, :conformsTo, :identifier, :keyword, :landingPage, :modified,
                          :publisher, :competencyQuestion, :designedForTask, :endorsedBy,
                          :hasFormalityLevel, :knownUsage, :semanticArtefactRelation, :status
                          # contactPoint, metrics should be handeled in specifi way because they are hashes
            
            # special SemanticArtefact attrs
            attr_accessor :distributions, :ontology

            def initialize(artefact_id)
                create_artefact(artefact_id)
            end

            def self.find(artefact_id)
                new(artefact_id)
            end
          
            def self.goo_attrs_to_load(attributes = [], level = 0)
                includes_attributes = if attributes.empty?
                                        default_attributes
                                    elsif attributes.first == :all
                                        all_attributes
                                    else
                                        attributes
                                    end
                ontology_includes_attributes = change_artefact_to_ontology_attrs(includes_attributes)
                submission_includes_attributes = change_artefact_to_submission_attrs(includes_attributes)

                ontology_attrs_loaded = ontology_includes_attributes.empty? ? [] : Ontology.goo_attrs_to_load(ontology_includes_attributes, level) 

                # TO-DO: we have to handle the case of attributes that are hashes like metrics, contact ..etc
                submission_attrs_loaded = submission_includes_attributes.empty? ? [] : OntologySubmission.goo_attrs_to_load(submission_includes_attributes, level)

                change_ontology_to_artefact_attrs(ontology_attrs_loaded) + change_submission_to_artefact_attrs(submission_attrs_loaded)
            end

            def bring(*attributes)
                attributes = [attributes] unless attributes.is_a?(Array)

                ontology_attributes_to_bring = self.class.change_artefact_to_ontology_attrs(attributes)
                @ontology.bring(*ontology_attributes_to_bring)
                map_ontology_to_artefact
                
                latest = @ontology.latest_submission(status: :any)
                submission_attributes_to_bring = self.class.change_artefact_to_submission_attrs(attributes)
                if latest
                    latest.bring(*submission_attributes_to_bring)
                    map_submission_to_artefact(latest)
                end
            end

            def self.all_artefacts(options = {})
                allow_views = options[:allow_views]
                to_bring_from_ontology = change_artefact_to_ontology_attrs(options[:includes]) if options[:includes]
                to_bring_from_submission = change_artefact_to_submission_attrs(options[:includes]) if options[:includes]
                if allow_views
                    onts = Ontology.where.include(Ontology.goo_attrs_to_load(to_bring_from_ontology + to_bring_from_submission)).to_a
                else
                    onts = Ontology.where.filter(Goo::Filter.new(:viewOf).unbound).include(Ontology.goo_attrs_to_load(includes_param)).to_a
                end
                onts
            end

            def latest_distribution(status)
                latest = @ontology.latest_submission(status)
                SemanticArtefactDistribution.new(latest)
            end

            def distribution(dist_id)
                @distributions.find { |dist| dist.instance_variable_get(:@distributionId).to_s == dist_id }
            end

            def all_distributions(options = {})
                status = options[:status]
                to_bring = options[:includes] if options[:includes]
                @distributions.each do |dist|
                    dist.bring(*to_bring)
                end
                return @distributions
            end

            private

            def create_artefact(artefact_id)
                ont = Ontology.find(artefact_id).include(:acronym).first

                return nil if ont.nil?
                
                @ontology = ont
                @acronym = ont.acronym
                @type = "http://www.isibang.ac.in/ns/mod#Semanticartefact"
                @id = ont.id
            end

            def self.default_attributes
                [
                    # ontology attrs
                    :id, :acronym, :type, :title, :accessRights, :group, :theme, :creator,
                    # submission attrs
                    :URI, :description, :language, :license,
                ]
            end
            
            def self.optional_attributes
                [
                    # ontology attrs
                    :hasEvaluation, :usedInProject,
                    #submission attrs
                    :rights, :conformsTo, :identifier, :keyword, :landingPage, :modified,
                    :publisher, :competencyQuestion, :designedForTask, :endorsedBy,
                    :hasFormalityLevel, :knownUsage, :semanticArtefactRelation, :status
                ]
            end
        
            def self.all_attributes
                default_attributes + optional_attributes
            end


            # Map with ontology
            def map_ontology_to_artefact
                if @ontology
                    @ontology.instance_variables.each do |var|
                        ontology_key = var.to_s.delete('@').to_sym
                        artefact_key = self.class.ontology_artefact_mapping[ontology_key]
                        next unless artefact_key
                
                        value = @ontology.instance_variable_get(var)
                        if ontology_key == :submissions
                            distributions = []
                            value.each do |submission|
                                distributions << SemanticArtefactDistribution.new(submission)
                            end
                            value = distributions
                        end
                        send("#{artefact_key}=", value)
                    end
                end
            end
          
            def self.artefact_ontology_mapping
                # id, acronym and type are defined during initialization
                {
                    title: :name,
                    accessRights: :viewingRestriction,
                    creator: :hasCreator,
                    group: :group,
                    theme: :hasDomain,
                    hasEvaluation: :reviews,
                    usedInProject: :projects,
                    distributions: :submissions,
                }

            end

            def self.ontology_artefact_mapping
                artefact_ontology_mapping.invert
            end

            def self.change_artefact_to_ontology_attrs(attributes)
                attributes.dup.map { |attr| artefact_ontology_mapping[attr] }.compact
            end

            def self.change_ontology_to_artefact_attrs(attributes)
                attributes.dup.map { |attr| ontology_artefact_mapping[attr] }.compact
            end

            # Mapping with submission
            def map_submission_to_artefact(latest)
                if latest
                    latest.instance_variables.each do |var|
                        submission_key = var.to_s.delete('@').to_sym
                        artefact_key = self.class.submission_artefact_mapping[submission_key]
                        next unless artefact_key
                        value = latest.instance_variable_get(var)
                        send("#{artefact_key}=", value)
                    end

                end
            end


            def self.artefact_submission_mapping
                {
                    URI: :URI,
                    description: :description,
                    language: :naturalLanguage,
                    license: :hasLicense,
                    rights: :copyrightHolder,
                    conformsTo: :conformsToKnowledgeRepresentationParadigm,
                    identifier: :identifier,
                    keyword: :keywords,
                    landingPage: :documentation,
                    modified: :modificationDate,
                    publisher: :publisher,
                    competencyQuestion: :competencyQuestion,
                    designedForTask: :designedForOntologyTask,
                    endorsedBy: :endorsedBy,
                    hasFormalityLevel: :hasFormalityLevel,
                    knownUsage: :knownUsage,
                    semanticArtefactRelation: :ontologyRelatedTo,
                    status: :status,
                }
            end

            def self.submission_artefact_mapping
                artefact_submission_mapping.invert
            end

            def self.change_artefact_to_submission_attrs(attributes)
                attributes.dup.map { |attr| artefact_submission_mapping[attr] }.compact
            end

            def self.change_submission_to_artefact_attrs(attributes)
                attributes.dup.map { |attr| submission_artefact_mapping[attr] }.compact
            end
           
        end

    end
end
  