# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2019 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'fileutils'
require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/container'
require 'java_buildpack/util/java_main_utils'

module JavaBuildpack
  module Container

    # Encapsulates the detect, compile, and release functionality for applications running Spring Boot CLI
    # applications.
    class Jeus < JavaBuildpack::Component::VersionedDependencyComponent

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_tar
        install_jeus
        update_jeus_property
        update_configuration
        copy_application
        copy_additional_libraries
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        #@droplet.environment_variables.add_environment_variable 'JAVA_OPTS', '$JAVA_OPTS'
        #@droplet.java_opts
        #        .add_system_property('jboss.http.port', '$PORT')
        #        .add_system_property('java.net.preferIPv4Stack', true)
        #        .add_system_property('java.net.preferIPv4Addresses', true)

        #[
        #  @droplet.environment_variables.as_env_vars,
        #  @droplet.java_home.as_env_var,
        #  'exec',
        #  "$PWD/#{(@droplet.sandbox + 'bin/standalone.sh').relative_path_from(@droplet.root)}",
        #  '-b',
        #  '0.0.0.0'
        #].compact.join(' ')
        @droplet.environment_variables.add_environment_variable 'JAVA_OPTS', '$JAVA_OPTS'
        @droplet.java_opts
                .add_system_property('jeus.scf.group-id', 'jeus_buildpack')
        [
          @droplet.environment_variables.as_env_vars,
          @droplet.java_home.as_env_var,
          'exec',
          "$PWD/#{(@droplet.sandbox + 'bin/startCloudServer').relative_path_from(@droplet.root)}",
          '-u jeus',
          '-p jeus',
          '-domain domain1',
          '-server adminServer'
        ].compact.join(' ')

      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        web_inf? && !JavaBuildpack::Util::JavaMainUtils.main_class(@application)
      end

      private

      def copy_application
        FileUtils.mkdir_p root
        @application.root.children.each { |child| FileUtils.cp_r child, root }
      end

      def copy_additional_libraries
        web_inf_lib = root + 'WEB-INF/lib'
        @droplet.additional_libraries.each { |additional_library| FileUtils.cp_r additional_library, web_inf_lib }
      end

      def create_dodeploy
        FileUtils.touch(webapps + 'ROOT.war.dodeploy')
      end

      def root
        webapps + 'ROOT.war'
      end

      def update_configuration
        domain_config = @droplet.sandbox + 'domains/domain1/config/domain.xml'

        #TODO: app id를 사용자가 지정할 수 있게 해야함
        #TODO: http port설정해야 할 수 있음
        modified = domain_config.read
                                .gsub(%r{<id>BOOT</id>}, 
                                '<id>ROOT.war</id>')
                                .gsub(%r{<path>/home/vcap/app</path>}, 
                                "<path>ROOT.war</path>")
                                .gsub(%r{<target-all-servers>true</target-all-servers>}, 
                                "<type>WAR</type>\n<target-all-servers>true</target-all-servers>")
        domain_config.open('w') { |f| f.write modified }
      end

      def webapps
        @droplet.sandbox + 'domains/domain1/servers/adminServer/.workspace/deployed'
      end

      def web_inf?
        (@application.root + 'WEB-INF').exist?
      end

      def install_jeus
        #FIXME : 임시로 JAVA_HOME을 export하는 구조는 이상하다
        jeus_home = "#{(@droplet.sandbox).relative_path_from(@droplet.root)}"
        @droplet.environment_variables.add_environment_variable 'JEUS_HOME', jeus_home
        java_path = "#{(@droplet.java_home.root).relative_path_from(@droplet.root)}"
        java_path = "#{@droplet.root.to_s}/#{java_path}"
        ant_cmd = [ 
                    'export',
                    @droplet.environment_variables.as_env_vars,
                    ';',
                    'export',
                    "JAVA_HOME=#{java_path}",
                    ';',
                    '/bin/sh',
                    @droplet.sandbox + 'lib/etc/ant/bin/ant',
                    '-f',
                    @droplet.sandbox + 'setup/build.xml',
                    'install'
                    ]
        shell(ant_cmd.compact.join(' '))
      end

      def update_jeus_property
        java_path = "$PWD/#{(@droplet.java_home.root).relative_path_from(@droplet.root)}"
        jeus_property = @droplet.sandbox + 'bin/jeus.properties'
        modified = jeus_property.read
                                .gsub(/JAVA_HOME=\".+\"/, "JAVA_HOME=#{java_path}")
        jeus_property.open('w') { |f| f.write modified }
      end

      def updata_datasource
        #TODO: datasource 설정 필요
      end

    end

  end
end
