use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'         => 'AxKit::XSP::BasicSession',
    'VERSION_FROM' => 'lib/AxKit/XSP/BasicSession.pm', # finds $VERSION
    'PREREQ_PM'    => {
        Apache::Session::Flex => 0,
        Apache::AxKit::Language::XSP::TaglibHelper => 0,
        Date::Format          => 0,
    },
);
