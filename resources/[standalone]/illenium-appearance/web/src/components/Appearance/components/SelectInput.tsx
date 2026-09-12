import { useContext, useRef } from 'react';
import styled, { ThemeContext } from 'styled-components';
import Select from 'react-select';

interface SelectInputProps {
  title: string;
  items: string[];
  defaultValue: string;
  clientValue: string;
  onChange: (value: string) => void;
}

const Container = styled.div`
  width: 100%;
  min-width: 0;

  display: flex;
  flex-direction: column;
  flex-grow: 1;

  > span {
    width: 100%;

    display: flex;
    justify-content: space-between;
    font-weight: 600;
    color: #a79eab;
    font-size: 12px;

    small:first-child {
      min-width: 0;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }

    small:last-child {
      flex: 0 0 auto;
      margin-left: 10px;
      color: #c994e0;
      white-space: nowrap;
    }
  }
`;

const customStyles: any = {
  control: (styles: any) => ({
    ...styles,
    marginTop: '9px',
    minHeight: '42px',
    background: 'rgba(4, 4, 6, .58)',
    fontSize: '14px',
    color: '#fff',
    border: '1px solid rgba(255,255,255,.08)',
    outline: 'none',
    boxShadow: 'none',
  }),
  placeholder: (styles: any) => ({
    ...styles,
    fontSize: '14px',
    color: '#fff',
  }),
  input: (styles: any) => ({
    ...styles,
    fontSize: '14px',
    color: '#fff',
  }),
  singleValue: (styles: any) => ({
    ...styles,
    fontSize: '14px',
    color: '#fff',
    border: 'none',
    outline: 'none',
  }),
  indicatorContainer: (styles: any) => ({
    ...styles,
    borderColor: '#fff',
    color: '#fff',
  }),
  dropdownIndicator: (styles: any) => ({
    ...styles,
    borderColor: '#fff',
    color: '#fff',
  }),
  menuPortal: (styles: any) => ({
    ...styles,
    color: '#fff',
    zIndex: 9999,
  }),
  menu: (styles: any) => ({
    ...styles,
    background: 'rgba(9, 8, 12, .98)',
    position: 'absolute',
    marginBottom: '10px',
    borderRadius: '4px',
    border: '1px solid rgba(176,125,203,.24)',
  }),
  menuList: (styles: any) => ({
    ...styles,
    background: 'rgba(9, 8, 12, .98)',
    borderRadius: '4px',
    '&::-webkit-scrollbar': {
      width: '10px',
    },
    '&::-webkit-scrollbar-track': {
      background: 'none',
    },
    '&::-webkit-scrollbar-thumb': {
      borderRadius: '4px',
      background: 'rgba(177,119,205,.62)',
    },
  }),
  option: (styles: any, { isFocused }: any) => ({
    ...styles,
    borderRadius: '4px',
    width: '97%',
    marginLeft: 'auto',
    marginRight: 'auto',
    background: isFocused ? 'rgba(104, 61, 130, .35)' : 'none',
  }),
};

const SelectInput = ({ title, items, defaultValue, clientValue, onChange }: SelectInputProps) => {
  const selectRef = useRef<any>(null);

  const handleChange = (event: any, { action }: any): void => {
    if (action === 'select-option') {
      onChange(event.value);
    }
  };

  const onMenuOpen = () => {
    setTimeout(() => {
      const selectedEl = document.getElementsByClassName("Select" + title + "__option--is-selected")[0];
      if (selectedEl) {
        selectedEl.scrollIntoView({ behavior: 'auto', block: 'start', inline: 'nearest' });
      }
    }, 100);
  };

  const themeContext = useContext(ThemeContext);
  customStyles.control.background = 'rgba(4, 4, 6, .58)';
  customStyles.menu.background = 'rgba(9, 8, 12, .98)';
  customStyles.menuList.background = 'rgba(9, 8, 12, .98)';

  return (
    <Container>
      <span>
        <small>{title}</small>
        <small>{clientValue}</small>
      </span>
      <Select
        ref={selectRef}
        styles={customStyles}
        options={items.map(item => ({ value: item, label: item }))}
        value={{ value: defaultValue, label: defaultValue }}
        onChange={handleChange}
        onMenuOpen={onMenuOpen}
        className={"Select" + title}
        classNamePrefix={"Select" + title}
        menuPortalTarget={document.body}
      />
    </Container>
  );
};

export default SelectInput;
