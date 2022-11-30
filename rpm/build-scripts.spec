Summary: Build scripts package to track infrastructure changelog
Name: build-scripts
Version: 0.1
Release: 0
BuildArch: noarch
License: GPLv2
URL: https://github.com/SailfishOS-SonyXperia/build
Source0: %{name}-%{version}.tar.gz

%description
%{summary}


%prep
%setup -q

%build

%install
install -Dm755 README.org %{buildroot}%{_defaultdocdir}/%{name}/README.org



%files
%defattr(-,root,root,-)
%verify (not mtime) %{_defaultdocdir}/%{name}/README.org
