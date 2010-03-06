module Bullet
  module ActiveRecord
    def self.enable
      require 'active_record'

      ::ActiveRecord::Relation.class_eval do
        alias_method :origin_to_a, :to_a
        def to_a
          records = origin_to_a
          if records.size > 1
            Bullet::Association.add_possible_objects(records)
            Bullet::Counter.add_possible_objects(records)
          elsif records.size == 1
            Bullet::Association.add_impossible_object(records.first)
            Bullet::Counter.add_impossible_object(records.first)
          end
          records
        end
      end

      ::ActiveRecord::AssociationPreload::ClassMethods.class_eval do
        alias_method :origin_preload_associations, :preload_associations
        def preload_associations(records, associations, preload_options={})
          records = [records].flatten.compact.uniq
          return if records.empty?
          records.each do |record|
            Bullet::Association.add_object_associations(record, associations)
          end
          Bullet::Association.add_eager_loadings(records, associations)
          origin_preload_associations(records, associations, preload_options={})
        end
      end

      ::ActiveRecord::FinderMethods.class_eval do
        alias_method :origin_find_with_associations, :find_with_associations
        def find_with_associations
          records = origin_find_with_associations
          associations = (@eager_load_values + @includes_values).uniq
          records.each do |record|
            Bullet::Association.add_object_associations(record, associations)
            Bullet::Association.call_association(record, associations)
          end
          Bullet::Association.add_eager_loadings(records, associations)
          records
        end
      end

      ::ActiveRecord::Associations::ClassMethods::JoinDependency.class_eval do
        alias_method :origin_construct_association, :construct_association
        def construct_association(record, join, row)
          associations = join.reflection.name
          Bullet::Association.add_object_associations(record, associations)
          Bullet::Association.call_association(record, associations)
          origin_construct_association(record, join, row)
        end
      end

    ::ActiveRecord::Associations::AssociationCollection.class_eval do
        # call one to many associations
        alias_method :origin_load_target, :load_target
        def load_target
          Bullet::Association.call_association(@owner, @reflection.name)
          origin_load_target
        end
      end
      
      ::ActiveRecord::Associations::AssociationProxy.class_eval do
        # call has_one and belong_to association
        alias_method :origin_load_target, :load_target
        def load_target
          # avoid stack level too deep
          result = origin_load_target
          Bullet::Association.call_association(@owner, @reflection.name) unless caller.to_s.include? 'load_target'
          Bullet::Association.add_possible_objects(result)
          result
        end
      end

      ::ActiveRecord::Associations::HasManyAssociation.class_eval do
        alias_method :origin_has_cached_counter?, :has_cached_counter?

        def has_cached_counter?
          result = origin_has_cached_counter?
          Bullet::Counter.add_counter_cache(@owner, @reflection.name) unless result
          result
        end
      end

      ::ActiveRecord::Associations::HasManyThroughAssociation.class_eval do
        alias_method :origin_has_cached_counter?, :has_cached_counter?

        def has_cached_counter?
          result = origin_has_cached_counter?
          Bullet::Counter.add_counter_cache(@owner, @reflection.name) unless result
          result
        end
      end
      
      ::ActiveRecord::Associations::HasManyThroughAssociation.class_eval do
        alias_method :origin_has_cached_counter?, :has_cached_counter?
        def has_cached_counter?
          result = origin_has_cached_counter?
          Bullet::Counter.add_counter_cache(@owner, @reflection.name) unless result
          result
        end
      end
    end
  end
end
