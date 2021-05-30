function parseRowNodes() {
  let rowNodes = document.querySelectorAll('.-row');
  let tempSiblingNodes = [];
  let tempNode;
  for (let i of rowNodes) {
    tempSiblingNodes = [];
    tempNode = i;

    while(tempNode = tempNode.nextElementSibling){
      if (tempNode.classList.contains('-row')){
        break;
      }
      if ([].some.call(tempNode.classList, c => /col-.*/.test(c))){
        tempSiblingNodes.push(tempNode);
      }  
    }

    let row = document.createElement('div')
    row.classList.add('row');
    for (let n of tempSiblingNodes){
      row.appendChild(n);
    }
    i.parentElement.insertBefore(row, i.nextElementSibling);
  }
}

document.addEventListener('DOMContentLoaded', parseRowNodes(), false);